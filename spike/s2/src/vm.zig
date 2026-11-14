// 스파이크 2: CodeAct의 실행 쪽. 버리는 코드다. 스파이크 1에서 확인한 것을 줄여 옮겼다.
// run 도구 하나가 Cyber 스크립트를 받아 검증하고, 상한을 걸어 실행하고, 결과를 글로 조립한다.
const std = @import("std");
const c = @import("cyber_c");
const jail = @import("jail.zig");

var g_io: std.Io = undefined;
var g_gpa: std.mem.Allocator = undefined;
var g_vm: ?*c.CLVM = null;
var g_out: std.ArrayList(u8) = .empty;
pub var trace: *const fn (line: []const u8) void = undefined;

fn B(s: []const u8) c.CLBytes {
    return .{ .ptr = @constCast(s.ptr), .len = s.len };
}
fn S(b: c.CLBytes) []const u8 {
    if (b.len == 0) return "";
    return b.ptr[0..b.len];
}
fn printer(_: ?*c.CLThread, str: c.CLBytes) callconv(.c) void {
    g_out.appendSlice(g_gpa, S(str)) catch {};
}

const Kind = enum { read, write, exec };
const Request = struct { kind: Kind, a: []u8, b: []u8 };
var g_reqs: std.ArrayList(Request) = .empty;
var g_calls: usize = 0;

fn takeStr(t: ?*c.CLThread) []u8 {
    var s = c.cl_thread_str(t);
    const copy = g_gpa.dupe(u8, S(c.cl_str_bytes(s))) catch unreachable;
    c.cl_str_deinit(t, &s);
    return copy;
}
// 호스트 함수의 인자 읽기는 순서가 정해져 있다: 반환 슬롯(cl_thread_ret)을 먼저, 그다음 매개변수를 선언 순서대로.
// 순서를 어기면 프로세스가 죽는다(스파이크에서 겪었다). 본체에서는 생성된 바인딩 층 한 곳이 이 순서를 책임진다.
fn retSlot(t: ?*c.CLThread) *c.CLValue {
    return @ptrCast(@alignCast(c.cl_thread_ret(t, @sizeOf(c.CLValue))));
}
fn newRequest(t: ?*c.CLThread, ret: *c.CLValue, spec: []const u8, kind: Kind, a: []u8, b: []u8) ?*c.CLFuture {
    g_reqs.append(g_gpa, .{ .kind = kind, .a = a, .b = b }) catch unreachable;
    const f = c.cl_future_new(t, c.cl_find_type(c.cl_thread_vm(t), B(spec)), g_reqs.items.len);
    ret.* = @intFromPtr(f);
    g_calls += 1;
    return f;
}
fn cap_read(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret = retSlot(t);
    const f = newRequest(t, ret, "Future[!str]", .read, takeStr(t), &.{});
    complete(c.cl_thread_vm(t), f.?); // 읽기는 승인 없이 바로 한다
    return c.CL_RET_OK;
}
fn cap_write(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret = retSlot(t);
    const path = takeStr(t);
    const text = takeStr(t);
    _ = newRequest(t, ret, "Future[!void]", .write, path, text);
    return c.CL_RET_OK;
}
fn cap_exec(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret = retSlot(t);
    _ = newRequest(t, ret, "Future[!str]", .exec, takeStr(t), &.{});
    return c.CL_RET_OK;
}
// 문자열 결과는 Future[!str]을 str 값으로 완료한다. 값은 Future가 소유한다.
fn completeStr(vm: ?*c.CLVM, f: *c.CLFuture, data: []const u8) void {
    const s = c.cl_str_init(c.cl_vm_main_thread(vm), B(data));
    _ = c.cl_future_complete(vm, f, &s);
}
fn fail(vm: ?*c.CLVM, f: *c.CLFuture, name: []const u8) void {
    _ = c.cl_future_complete_error(vm, f, c.cl_error(vm, B(name)));
}
fn complete(vm: ?*c.CLVM, f: *c.CLFuture) void {
    const req = g_reqs.items[c.cl_future_tag(f) - 1];
    switch (req.kind) {
        .read => {
            const dir = std.Io.Dir.cwd().openDir(g_io, jail.work_dir, .{}) catch return fail(vm, f, "NotFound");
            const data = dir.readFileAlloc(g_io, req.a, g_gpa, .limited(4 << 20)) catch return fail(vm, f, "NotFound");
            completeStr(vm, f, data);
        },
        .write => {
            if (!jail.writable(req.a)) return fail(vm, f, "Denied");
            const dir = std.Io.Dir.cwd().openDir(g_io, jail.work_dir, .{}) catch return fail(vm, f, "WriteFailed");
            dir.writeFile(g_io, .{ .sub_path = req.a, .data = req.b }) catch return fail(vm, f, "WriteFailed");
            _ = c.cl_future_complete(vm, f, null);
        },
        .exec => {
            const r = jail.sh(g_gpa, g_io, req.a) catch return fail(vm, f, "ExecFailed");
            const both = std.mem.concat(g_gpa, u8, &.{ r.stdout, r.stderr }) catch unreachable;
            completeStr(vm, f, both);
        },
    }
}

const fs_src =
    \\#[bind] fn read_async(path str) -> Future[!str]
    \\#[bind] fn write_async(path str, text str) -> Future[!void]
    \\fn read(path str) -> !str:
    \\    return read_async(path).await()
    \\fn write(path str, text str) -> !void:
    \\    return write_async(path, text).await()
    \\
;
const proc_src =
    \\#[bind] fn exec_async(cmd str) -> Future[!str]
    \\fn exec(cmd str) -> !str:
    \\    return exec_async(cmd).await()
    \\
;
fn bind(mod: ?*c.CLSym, name: []const u8, f: *const fn (?*c.CLThread) callconv(.c) c.CLRet) void {
    c.cl_mod_add_func(mod, B(name), .{ .ptr = @ptrCast(f), .kind = c.CL_BIND_FUNC_VM });
}
fn loader(vm: ?*c.CLVM, mod: ?*c.CLSym, uri: c.CLBytes, res: [*c]c.CLLoaderResult) callconv(.c) bool {
    const name = S(uri);
    if (std.mem.eql(u8, name, "fs")) {
        bind(mod, "read_async", cap_read);
        bind(mod, "write_async", cap_write);
        res.*.src = B(fs_src);
        return true;
    }
    if (std.mem.eql(u8, name, "proc")) {
        bind(mod, "exec_async", cap_exec);
        res.*.src = B(proc_src);
        return true;
    }
    if (std.mem.eql(u8, name, "c") or std.mem.eql(u8, name, "test")) return false;
    return c.cl_default_loader(vm, mod, uri, res);
}

fn config() c.CLEvalConfig {
    var cfg = std.mem.zeroes(c.CLEvalConfig);
    cfg.persist_main = true;
    cfg.deny_raw_ptrs = true;
    cfg.deny_spawn = true; // 능력은 eval 스레드에서만 불린다
    return cfg;
}

pub fn init(gpa: std.mem.Allocator, io: std.Io) void {
    g_gpa = gpa;
    g_io = io;
    g_vm = c.cl_vm_init();
    c.cl_vm_set_loader(g_vm, loader);
    c.cl_vm_set_printer(g_vm, printer);
    c.cl_vm_set_stack_limit(g_vm, 8 << 20);
    // 머리말: 능력 모듈을 미리 들여 둔다. persist_main이라 다음 eval에서 그대로 보인다.
    prelude();
}

fn prelude() void {
    var res: c.CLEvalResult = undefined;
    _ = c.cl_vm_evalx(g_vm, B("prelude"), B("use fs\nuse proc\n"), config(), &res);
}

// 실패한 eval이나 검증 뒤 VM이 reset을 기다리면(cl_vm_reset_pending) 머리말을 다시 돌리고 모델에게 알린다.
fn resetNote() []const u8 {
    if (!c.cl_vm_reset_pending(g_vm)) return "";
    prelude();
    trace("    [세션 reset]\n");
    return "the session was reset: variables and functions of earlier runs are gone (fs and proc are imported again)\n";
}

var g_gen = std.atomic.Value(u32).init(0);
fn timer(vm: ?*c.CLVM, gen: u32, ms: i64) void {
    var left = ms;
    while (left > 0 and g_gen.load(.monotonic) == gen) : (left -= 50) std.Io.sleep(g_io, .fromMilliseconds(50), .awake) catch {};
    if (g_gen.load(.monotonic) == gen) c.cl_vm_interrupt(vm);
}

pub const RunResult = struct { text: []const u8, is_error: bool, kind: []const u8, calls: usize };

fn summary(vm: ?*c.CLVM, compile: bool) []const u8 {
    const s = if (compile) c.cl_vm_compile_error_summary(vm) else c.cl_vm_error_summary(vm);
    defer c.cl_vm_freeb(vm, s);
    return g_gpa.dupe(u8, S(s)) catch "";
}

pub fn runCode(code: []const u8) RunResult {
    const vm = g_vm;
    g_out.clearRetainingCapacity();
    g_reqs.clearRetainingCapacity();
    g_calls = 0;

    // 1. 검증: 세션 VM에서 실행 없이 컴파일만 한다. 세션의 변수와 함수가 보이고, 틀린 코드는 한 줄도 실행되지 않는다.
    if (c.cl_vm_validate(vm, B(code)) != c.CL_SUCCESS) {
        const msg = summary(vm, true);
        return .{ .text = std.fmt.allocPrint(g_gpa, "compile error (nothing was executed)\n{s}{s}", .{ msg, resetNote() }) catch "", .is_error = true, .kind = "compile error", .calls = 0 };
    }
    // 2. 상한을 걸고 실행.
    c.cl_vm_set_fuel(vm, 200_000_000);
    c.cl_vm_set_memory_limit(vm, @intCast(c.cl_vm_memory_used(vm) + (64 << 20)));
    const gen = g_gen.fetchAdd(1, .monotonic) + 1;
    const th = std.Thread.spawn(.{}, timer, .{ vm, gen, 30_000 }) catch unreachable;
    var res: c.CLEvalResult = undefined;
    var code_r = c.cl_vm_evalx(vm, B("main"), B(code), config(), &res);
    // 3. 승인 대기: 스크립트는 멈춰 있고 루프가 결정한다. 스파이크는 모두 승인하고 무엇을 승인했는지 찍는다.
    while (code_r == c.CL_AWAIT) {
        var buf: [16]?*c.CLFuture = undefined;
        const n = c.cl_vm_pending_futures(vm, @ptrCast(&buf), buf.len);
        var pick: ?*c.CLFuture = null;
        for (buf[0..@min(n, buf.len)]) |f| {
            const tag = c.cl_future_tag(f);
            if (tag == 0) continue;
            if (pick == null or tag < c.cl_future_tag(pick)) pick = f;
        }
        if (pick == null) {
            c.cl_vm_abandon(vm);
            code_r = c.CL_ERROR_INTERRUPT;
            break;
        }
        const req = g_reqs.items[c.cl_future_tag(pick) - 1];
        trace(std.fmt.allocPrint(g_gpa, "    [승인] {s} {s}\n", .{ @tagName(req.kind), req.a[0..@min(req.a.len, 100)] }) catch "");
        complete(vm, pick.?);
        code_r = c.cl_vm_resume(vm, &res);
    }
    _ = g_gen.fetchAdd(1, .monotonic);
    th.join();

    // 4. 결과 조립: 출력, 마지막 표현식 값, 실패의 종류.
    var out: std.ArrayList(u8) = .empty;
    const max = 6000;
    if (g_out.items.len > max) {
        out.appendSlice(g_gpa, g_out.items[0..max]) catch {};
        out.print(g_gpa, "\n... output truncated ({d} bytes total)\n", .{g_out.items.len}) catch {};
    } else out.appendSlice(g_gpa, g_out.items) catch {};
    switch (code_r) {
        c.CL_SUCCESS => {
            if (res.res != null and res.res_t != c.CL_TYPE_VOID) {
                const d = c.cl_value_desc(vm, res.res_t, res.res);
                out.print(g_gpa, "=> {s}\n", .{S(d)}) catch {};
                c.cl_vm_freeb(vm, d);
            }
            if (out.items.len == 0) out.print(g_gpa, "ok ({d} capability calls)\n", .{g_calls}) catch {};
            return .{ .text = out.items, .is_error = false, .kind = "ok", .calls = g_calls };
        },
        c.CL_ERROR_PANIC => {
            out.print(g_gpa, "panic\n{s}\ntop-level variables were reset (functions and imports are kept)\n", .{summary(vm, false)}) catch {};
            return .{ .text = out.items, .is_error = true, .kind = "panic", .calls = g_calls };
        },
        c.CL_ERROR_INTERRUPT => {
            out.print(g_gpa, "interrupted (fuel or time limit)\ntop-level variables were reset (functions and imports are kept)\n", .{}) catch {};
            return .{ .text = out.items, .is_error = true, .kind = "interrupted", .calls = g_calls };
        },
        else => {
            out.print(g_gpa, "error code {d}\n{s}\n{s}", .{ code_r, summary(vm, code_r == c.CL_ERROR_COMPILE), resetNote() }) catch {};
            return .{ .text = out.items, .is_error = true, .kind = "error", .calls = g_calls };
        },
    }
}
