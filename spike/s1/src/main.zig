// 스파이크 1: 호스트 경계. 버리는 코드다.
// Zig 호스트가 libcyber VM을 띄우고, 능력(호스트 함수)을 꽂고, 상한을 걸고,
// 승인 대기(CL_AWAIT)를 VM 밖에서 처리하는 흐름을 항목별로 확인한다.
// 결과 해석은 docs/spikes/ 의 검토 문서에 있다.
const std = @import("std");
const c = @import("cyber_c");

var g_io: std.Io = undefined;
var g_gpa: std.mem.Allocator = undefined;

// ---------- 작은 도우미 ----------

fn B(s: []const u8) c.CLBytes {
    return .{ .ptr = @constCast(s.ptr), .len = s.len };
}
fn S(b: c.CLBytes) []const u8 {
    if (b.len == 0) return "";
    return b.ptr[0..b.len];
}

// print 가로채기: 스크립트의 출력은 여기 모인다. 에이전트에서는 이것이 tool_result가 된다.
var g_out: std.ArrayList(u8) = .empty;
fn printer(_: ?*c.CLThread, str: c.CLBytes) callconv(.c) void {
    g_out.appendSlice(g_gpa, S(str)) catch {};
}

// ---------- 요청 표 (ADR 0011) ----------
// 능력은 일을 하지 않고 요청만 적은 뒤 미완료 Future를 돌려준다.
// Future의 태그가 요청 번호다(1부터). 호스트는 Future 포인터를 보관하지 않는다.

const Kind = enum { read, write, exec };
const Request = struct {
    kind: Kind,
    a: []u8, // 경로 또는 명령
    b: []u8, // 쓸 내용
    done: bool = false,
};
var g_reqs: std.ArrayList(Request) = .empty;
var g_calls: usize = 0; // 능력이 불린 횟수

// cyber 0.4.9는 !str 값을 복사하지 못한다(core:2918 컴파일 오류). 그래서 Future[!str]을 쓸 수 없다.
// 우회: 능력은 Future[!int]로 손잡이(handle)를 돌려주고, 래퍼가 take(h)로 문자열을 꺼낸다.
var g_results: std.ArrayList([]u8) = .empty;
fn putResult(data: []const u8) i64 {
    g_results.append(g_gpa, g_gpa.dupe(u8, data) catch unreachable) catch unreachable;
    return @intCast(g_results.items.len - 1);
}
fn cap_take(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret: *c.CLstr = @ptrCast(@alignCast(c.cl_thread_ret(t, @sizeOf(c.CLstr))));
    const h: usize = @intCast(c.cl_thread_int(t));
    ret.* = c.cl_str_init(t, B(g_results.items[h]));
    g_gpa.free(g_results.items[h]);
    g_results.items[h] = &.{};
    return c.CL_RET_OK;
}

fn clearRequests() void {
    for (g_reqs.items) |r| {
        g_gpa.free(r.a);
        g_gpa.free(r.b);
    }
    g_reqs.clearRetainingCapacity();
}

fn takeStr(t: ?*c.CLThread) []u8 {
    var s = c.cl_thread_str(t);
    const copy = g_gpa.dupe(u8, S(c.cl_str_bytes(s))) catch unreachable;
    c.cl_str_deinit(t, &s); // 값 매개변수는 호스트가 소유한다
    return copy;
}

fn newRequest(t: ?*c.CLThread, ret: *c.CLValue, future_spec: []const u8, kind: Kind, a: []u8, b: []u8) ?*c.CLFuture {
    const vm = c.cl_thread_vm(t);
    const future_t = c.cl_find_type(vm, B(future_spec));
    g_reqs.append(g_gpa, .{ .kind = kind, .a = a, .b = b }) catch unreachable;
    const tag: u64 = g_reqs.items.len;
    const f = c.cl_future_new(t, future_t, tag);
    ret.* = @intFromPtr(f);
    g_calls += 1;
    return f;
}

// 등급 read: 승인이 필요 없다. 호스트 함수 안에서 바로 일을 하고 완료된 Future를 돌려준다.
fn cap_read(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret: *c.CLValue = @ptrCast(@alignCast(c.cl_thread_ret(t, @sizeOf(c.CLValue))));
    const path = takeStr(t);
    const f = newRequest(t, ret, "Future[!int]", .read, path, g_gpa.dupe(u8, "") catch unreachable);
    completeRequest(c.cl_thread_vm(t), f.?, true);
    return c.CL_RET_OK;
}

// 등급 write: 요청만 적고 미완료 Future를 돌려준다. 실제 쓰기는 승인 뒤 루프가 한다.
fn cap_write(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret: *c.CLValue = @ptrCast(@alignCast(c.cl_thread_ret(t, @sizeOf(c.CLValue))));
    const path = takeStr(t);
    const text = takeStr(t);
    _ = newRequest(t, ret, "Future[!void]", .write, path, text);
    return c.CL_RET_OK;
}

// 등급 exec: 같은 모양. 프로세스 실행은 승인 뒤 루프가 한다.
fn cap_exec(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret: *c.CLValue = @ptrCast(@alignCast(c.cl_thread_ret(t, @sizeOf(c.CLValue))));
    const cmd = takeStr(t);
    _ = newRequest(t, ret, "Future[!int]", .exec, cmd, g_gpa.dupe(u8, "") catch unreachable);
    return c.CL_RET_OK;
}

// 기본값 매개변수 확인용: limit을 그대로 돌려준다.
fn cap_peek(t: ?*c.CLThread) callconv(.c) c.CLRet {
    const ret: *i64 = @ptrCast(@alignCast(c.cl_thread_ret(t, @sizeOf(i64))));
    const path = takeStr(t);
    g_gpa.free(path);
    ret.* = c.cl_thread_int(t);
    return c.CL_RET_OK;
}

// 승인된(또는 승인이 필요 없는) 요청의 실제 작업. 세계에 닿는 코드는 여기 한 곳뿐이다.
fn completeRequest(vm: ?*c.CLVM, f: *c.CLFuture, approved: bool) void {
    const tag = c.cl_future_tag(f);
    const req = &g_reqs.items[tag - 1];
    req.done = true;
    if (!approved) {
        _ = c.cl_future_complete_error(vm, f, c.cl_error(vm, B("Denied")));
        return;
    }
    switch (req.kind) {
        .read => {
            const data = std.Io.Dir.cwd().readFileAlloc(g_io, req.a, g_gpa, .limited(1 << 20)) catch {
                _ = c.cl_future_complete_error(vm, f, c.cl_error(vm, B("NotFound")));
                return;
            };
            defer g_gpa.free(data);
            var h = putResult(data);
            _ = c.cl_future_complete(vm, f, &h);
        },
        .write => {
            std.Io.Dir.cwd().writeFile(g_io, .{ .sub_path = req.a, .data = req.b }) catch {
                _ = c.cl_future_complete_error(vm, f, c.cl_error(vm, B("WriteFailed")));
                return;
            };
            _ = c.cl_future_complete(vm, f, null);
        },
        .exec => {
            const r = std.process.run(g_gpa, g_io, .{ .argv = &.{ "/bin/sh", "-c", req.a } }) catch {
                _ = c.cl_future_complete_error(vm, f, c.cl_error(vm, B("ExecFailed")));
                return;
            };
            defer g_gpa.free(r.stdout);
            defer g_gpa.free(r.stderr);
            var h = putResult(r.stdout);
            _ = c.cl_future_complete(vm, f, &h);
        },
    }
}

// ---------- 호스트 로더 ----------
// 스크립트의 `use fs`가 여기로 온다. 호스트 모듈은 #[bind] 선언과 동기 래퍼를 소스로 돌려준다.
// 모델에게는 래퍼(fs.read, fs.write)만 보이고, 멈췄다 재개되는 것은 모른다.

const fs_src =
    \\#[bind] fn read_async(path str) -> Future[!int]
    \\#[bind] fn take(h int) -> str
    \\#[bind] fn write_async(path str, text str) -> Future[!void]
    \\#[bind] fn peek(path str, limit int = 100) -> int
    \\fn read(path str) -> !str:
    \\    h := read_async(path).await()!
    \\    return take(h)
    \\fn write(path str, text str) -> !void:
    \\    return write_async(path, text).await()
    \\
;
const fs_src_nodefault =
    \\#[bind] fn read_async(path str) -> Future[!int]
    \\#[bind] fn take(h int) -> str
    \\#[bind] fn write_async(path str, text str) -> Future[!void]
    \\fn read(path str) -> !str:
    \\    h := read_async(path).await()!
    \\    return take(h)
    \\fn write(path str, text str) -> !void:
    \\    return write_async(path, text).await()
    \\
;
const proc_src =
    \\#[bind] fn exec_async(cmd str) -> Future[!int]
    \\#[bind] fn take(h int) -> str
    \\fn exec(cmd str) -> !str:
    \\    h := exec_async(cmd).await()!
    \\    return take(h)
    \\
;

var g_fs_default_param = false;
var g_denied_modules: usize = 0;

fn loader(vm: ?*c.CLVM, mod: ?*c.CLSym, uri: c.CLBytes, res: [*c]c.CLLoaderResult) callconv(.c) bool {
    const name = S(uri);
    if (std.mem.eql(u8, name, "fs")) {
        c.cl_mod_add_func(mod, B("read_async"), .{ .ptr = @ptrCast(&cap_read), .kind = c.CL_BIND_FUNC_VM });
        c.cl_mod_add_func(mod, B("take"), .{ .ptr = @ptrCast(&cap_take), .kind = c.CL_BIND_FUNC_VM });
        c.cl_mod_add_func(mod, B("write_async"), .{ .ptr = @ptrCast(&cap_write), .kind = c.CL_BIND_FUNC_VM });
        if (g_fs_default_param) {
            c.cl_mod_add_func(mod, B("peek"), .{ .ptr = @ptrCast(&cap_peek), .kind = c.CL_BIND_FUNC_VM });
            res.*.src = B(fs_src);
        } else {
            res.*.src = B(fs_src_nodefault);
        }
        res.*.manage_src = false;
        return true;
    }
    if (std.mem.eql(u8, name, "proc")) {
        c.cl_mod_add_func(mod, B("take"), .{ .ptr = @ptrCast(&cap_take), .kind = c.CL_BIND_FUNC_VM });
        c.cl_mod_add_func(mod, B("exec_async"), .{ .ptr = @ptrCast(&cap_exec), .kind = c.CL_BIND_FUNC_VM });
        res.*.src = B(proc_src);
        res.*.manage_src = false;
        return true;
    }
    // c 모듈(FFI와 raw 메모리)과 test 모듈은 스크립트에 주지 않는다.
    if (std.mem.eql(u8, name, "c") or std.mem.eql(u8, name, "test")) {
        g_denied_modules += 1;
        return false;
    }
    return c.cl_default_loader(vm, mod, uri, res);
}

// ---------- 실행: 에이전트 루프의 "한 스텝"에 해당 ----------

const Policy = struct {
    deny_prefix: []const u8 = "\x00none",
    cancel_at: i64 = -1, // 몇 번째 승인 질문에서 취소(Esc)할지
};
var g_asked: std.ArrayList(u64) = .empty; // 승인을 물은 요청 번호의 순서
var g_abandoned_foreign = false;

const Outcome = struct { code: c.CLResultCode, awaits: usize };

fn evalConfig() c.CLEvalConfig {
    var cfg = std.mem.zeroes(c.CLEvalConfig);
    cfg.persist_main = true;
    cfg.deny_raw_ptrs = true;
    return cfg;
}

fn run(vm: ?*c.CLVM, src: []const u8, policy: Policy) Outcome {
    g_out.clearRetainingCapacity();
    g_asked.clearRetainingCapacity();
    g_abandoned_foreign = false;
    clearRequests();
    var res: c.CLEvalResult = undefined;
    var code = c.cl_vm_evalx(vm, B("main"), B(src), evalConfig(), &res);
    var awaits: usize = 0;
    var answered: i64 = 0;
    while (code == c.CL_AWAIT) {
        awaits += 1;
        // 기다리는 Future 전부를 읽고, 우리 요청(태그 != 0) 중 번호가 가장 작은 것 하나를 고른다 (ADR 0016).
        var buf: [32]?*c.CLFuture = undefined;
        const n = c.cl_vm_pending_futures(vm, @ptrCast(&buf), buf.len);
        var pick: ?*c.CLFuture = null;
        var pick_tag: u64 = 0;
        for (buf[0..@min(n, buf.len)]) |f| {
            const tag = c.cl_future_tag(f);
            if (tag == 0 or tag > g_reqs.items.len) continue;
            if (pick == null or tag < pick_tag) {
                pick = f;
                pick_tag = tag;
            }
        }
        if (pick == null) {
            // 스크립트가 직접 만든 Future다. 호스트는 완료시킬 수 없으므로 버린다.
            g_abandoned_foreign = true;
            c.cl_vm_abandon(vm);
            code = c.CL_ERROR_INTERRUPT;
            break;
        }
        if (answered == policy.cancel_at) {
            c.cl_vm_abandon(vm);
            code = c.CL_ERROR_INTERRUPT;
            break;
        }
        answered += 1;
        g_asked.append(g_gpa, pick_tag) catch {};
        const req = g_reqs.items[pick_tag - 1];
        const approved = !std.mem.startsWith(u8, req.a, policy.deny_prefix);
        completeRequest(vm, pick.?, approved);
        code = c.cl_vm_resume(vm, &res);
    }
    return .{ .code = code, .awaits = awaits };
}

fn errorSummary(vm: ?*c.CLVM) []const u8 {
    const s = c.cl_vm_error_summary(vm);
    const copy = g_gpa.dupe(u8, S(s)) catch "";
    c.cl_vm_freeb(vm, s);
    return copy;
}

fn firstLine(s: []const u8) []const u8 {
    const t = std.mem.trim(u8, s, " \n");
    return t[0 .. std.mem.indexOfScalar(u8, t, '\n') orelse t.len];
}

fn newVm() ?*c.CLVM {
    const vm = c.cl_vm_init();
    c.cl_vm_set_loader(vm, loader);
    c.cl_vm_set_printer(vm, printer);
    return vm;
}

// ---------- 검사 목록 ----------

var g_pass: usize = 0;
var g_fail: usize = 0;
fn check(name: []const u8, ok: bool, comptime fmt: []const u8, args: anytype) void {
    if (ok) g_pass += 1 else g_fail += 1;
    std.debug.print("[{s}] {s}\n       ", .{ if (ok) "PASS" else "FAIL", name });
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

fn codeName(code: c.CLResultCode) []const u8 {
    return switch (code) {
        c.CL_SUCCESS => "SUCCESS",
        c.CL_AWAIT => "AWAIT",
        c.CL_ERROR_COMPILE => "COMPILE",
        c.CL_ERROR_PANIC => "PANIC",
        c.CL_ERROR_UNKNOWN => "UNKNOWN",
        c.CL_ERROR_INTERRUPT => "INTERRUPT",
        c.CL_ERROR_SUSPENDED => "SUSPENDED",
        else => "?",
    };
}

fn timerThread(vm: ?*c.CLVM, ms: i64) void {
    std.Io.sleep(g_io, .fromMilliseconds(ms), .awake) catch {};
    c.cl_vm_interrupt(vm);
}

fn nowMs() i64 {
    return std.Io.Timestamp.now(g_io, .awake).toMilliseconds();
}

// 재현: 호스트 모듈의 소스가 컴파일에 실패한 뒤 같은 VM에서 eval을 되풀이한다.
const bad_mod_src =
    \\#[bind] fn read_async(path str) -> Future[!str]
    \\fn read(path str) -> !str:
    \\    return read_async(path).await()
    \\
;
const bad_mod_src2 =
    \\fn read(path str) -> !str:
    \\    return undefined_thing
    \\
;
var g_bad_variant: u8 = 1;
fn badLoader(vm: ?*c.CLVM, mod: ?*c.CLSym, uri: c.CLBytes, res: [*c]c.CLLoaderResult) callconv(.c) bool {
    if (std.mem.eql(u8, S(uri), "fs")) {
        if (g_bad_variant == 1) c.cl_mod_add_func(mod, B("read_async"), .{ .ptr = @ptrCast(&cap_read), .kind = c.CL_BIND_FUNC_VM });
        res.*.src = B(if (g_bad_variant == 1) bad_mod_src else bad_mod_src2);
        res.*.manage_src = false;
        return true;
    }
    return c.cl_default_loader(vm, mod, uri, res);
}
fn crashRepro(variant: u8, persist: bool) void {
    g_bad_variant = variant;
    const vm = c.cl_vm_init();
    c.cl_vm_set_loader(vm, badLoader);
    c.cl_vm_set_printer(vm, printer);
    var i: usize = 0;
    while (i < 12) : (i += 1) {
        var res: c.CLEvalResult = undefined;
        const src = if (i % 2 == 0) "use fs\nprint(fs.read('x')!)\n" else "print('plain')\n";
        var cfg = evalConfig();
        cfg.persist_main = persist;
        const code = c.cl_vm_evalx(vm, B("main"), B(src), cfg, &res);
        std.debug.print("eval {d}: {s}\n", .{ i, codeName(code) });
    }
    std.debug.print("no crash\n", .{});
}

// spawn 관찰: 스레드 안의 능력 호출, 스레드 안의 무한 루프와 상한.
fn spawnProbe() void {
    const vm = newVm();
    const r1 = run(vm,
        \\use fs
        \\fn work(p str) -> int:
        \\    t := fs.read(p) !else 'ERR'
        \\    return t.len()
        \\f := spawn(work, {'/tmp/tars-agent-s1/in.txt'})
        \\print(f.await())
        \\
    , .{});
    std.debug.print("A. spawn 안의 능력 호출: code={s} 출력={s} | {s}\n", .{ codeName(r1.code), std.mem.trim(u8, g_out.items, "\n"), if (r1.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });

    const vm2 = newVm();
    c.cl_vm_set_fuel(vm2, 1_000_000);
    const th = std.Thread.spawn(.{}, timerThread, .{ vm2, 500 }) catch unreachable;
    const t0 = nowMs();
    std.debug.print("B. spawn 안의 무한 루프 (연료 1,000,000, 타이머 500ms). 돌아오지 않으면 막을 수단이 없는 것이다...\n", .{});
    const r2 = run(vm2,
        \\fn spin(n int) -> int:
        \\    k := n
        \\    while true:
        \\        k += 1
        \\    return k
        \\f := spawn(spin, {0})
        \\print(f.await())
        \\
    , .{});
    th.join();
    std.debug.print("B. code={s} {d}ms | {s}\n", .{ codeName(r2.code), nowMs() - t0, firstLine(errorSummary(vm2)) });
    const r3 = run(vm2, "print('alive after spawn')\n", .{});
    std.debug.print("B. 다음 eval: code={s} 출력={s}\n", .{ codeName(r3.code), std.mem.trim(u8, g_out.items, "\n") });
}

pub fn main(init: std.process.Init) !void {
    g_io = init.io;
    g_gpa = init.gpa;
    const scratch = "/tmp/tars-agent-s1";
    std.Io.Dir.cwd().createDirPath(g_io, scratch) catch {};

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "spawn")) return spawnProbe();
    if (args.len > 1 and std.mem.eql(u8, args[1], "crash")) return crashRepro(if (args.len > 2 and args[2][0] == '2') 2 else 1, !(args.len > 3));

    const ver = c.cl_full_version();
    std.debug.print("libcyber: {s}\n\n", .{S(ver)});

    // 1. 기본: eval, print 가로채기, 결과 값
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        const t0 = nowMs();
        const r = run(vm, "print('hello')\n1 + 2\n", .{});
        var res: c.CLEvalResult = undefined;
        const code2 = c.cl_vm_evalx(vm, B("main"), B("40 + 2\n"), evalConfig(), &res);
        var desc: []const u8 = "";
        if (code2 == c.CL_SUCCESS and res.res != null) {
            const d = c.cl_value_desc(vm, res.res_t, res.res);
            desc = g_gpa.dupe(u8, S(d)) catch "";
            c.cl_vm_freeb(vm, d);
        }
        check("1. eval, print 가로채기, 마지막 표현식 값", r.code == c.CL_SUCCESS and std.mem.eql(u8, g_out.items, "hello\n") and std.mem.endsWith(u8, desc, "42"), "출력={s} 결과값={s} 첫 eval 포함 {d}ms", .{ std.mem.trim(u8, g_out.items, "\n"), desc, nowMs() - t0 });
    }

    // 2. 능력 호출: 승인이 필요 없는 read는 CL_AWAIT 없이 끝난다
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        try std.Io.Dir.cwd().writeFile(g_io, .{ .sub_path = scratch ++ "/in.txt", .data = "line1\nline2\nline3\n" });
        const r = run(vm,
            \\use fs
            \\text := fs.read('/tmp/tars-agent-s1/in.txt')!
            \\print(text.split('\n').len())
            \\
        , .{});
        check("2. fs.read (등급 read): 호스트 함수 안에서 완료된 Future", r.code == c.CL_SUCCESS and r.awaits == 0 and g_calls == 1, "code={s} awaits={d} 출력={s} | {s}", .{ codeName(r.code), r.awaits, std.mem.trim(u8, g_out.items, "\n"), if (r.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });

        const r2 = run(vm,
            \\use fs
            \\r := fs.read('/tmp/tars-agent-s1/none.txt') !else 'fallback'
            \\print(r)
            \\
        , .{});
        check("2b. 능력의 오류는 오류 값으로 돌아간다 (error.NotFound)", r2.code == c.CL_SUCCESS and std.mem.eql(u8, g_out.items, "fallback\n"), "code={s} 출력={s} | {s}", .{ codeName(r2.code), std.mem.trim(u8, g_out.items, "\n"), if (r2.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });
    }

    // 3. 승인 흐름: 승인, 거부, 취소
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        const src =
            \\use fs
            \\fn save(names []str) -> int:
            \\    saved := 0
            \\    for names |name|:
            \\        try:
            \\            fs.write(name, 'data')!
            \\            saved += 1
            \\        else |err|:
            \\            print('not saved: %{name} (%{err})')
            \\    return saved
            \\print(save([]str{'/tmp/tars-agent-s1/a.txt', '/etc/tars-denied', '/tmp/tars-agent-s1/b.txt'}))
            \\
        ;
        const r = run(vm, src, .{ .deny_prefix = "/etc/" });
        const a_ok = if (std.Io.Dir.cwd().readFileAlloc(g_io, scratch ++ "/a.txt", g_gpa, .limited(100))) |d| std.mem.eql(u8, d, "data") else |_| false;
        check("3. fs.write 승인 둘, 거부 하나: 거부는 error.Denied", r.code == c.CL_SUCCESS and r.awaits == 3 and a_ok and std.mem.indexOf(u8, g_out.items, "error.Denied") != null and std.mem.endsWith(u8, g_out.items, "2\n"), "code={s} awaits={d} 출력={s}", .{ codeName(r.code), r.awaits, std.mem.trim(u8, g_out.items, "\n") });

        const r2 = run(vm,
            \\use fs
            \\fs.write('/tmp/tars-agent-s1/c.txt', 'data')!
            \\fs.write('/tmp/tars-agent-s1/d.txt', 'data')!
            \\print('not reached')
            \\
        , .{ .cancel_at = 1 });
        const d_missing = if (std.Io.Dir.cwd().access(g_io, scratch ++ "/d.txt", .{})) |_| false else |_| true;
        const r3 = run(vm, "print('still alive')\n", .{});
        check("3b. 두 번째 승인에서 취소: abandon, VM은 다음 스크립트를 받는다", r2.code == c.CL_ERROR_INTERRUPT and d_missing and r3.code == c.CL_SUCCESS, "취소 code={s} d.txt 없음={} 다음 eval={s}", .{ codeName(r2.code), d_missing, codeName(r3.code) });

        const r4 = run(vm,
            \\use proc
            \\out := proc.exec('echo hi; uname -s')!
            \\print(out.trim('\n'))
            \\
        , .{});
        check("3c. proc.exec: 승인 뒤 루프가 프로세스를 돌리고 stdout을 돌려준다", r4.code == c.CL_SUCCESS and r4.awaits == 1 and std.mem.startsWith(u8, g_out.items, "hi"), "code={s} 출력={s} | {s}", .{ codeName(r4.code), std.mem.trim(u8, g_out.items, "\n"), if (r4.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });

        // 버린 Future와 태그
        const r5 = run(vm,
            \\use fs
            \\_ = fs.write_async('/tmp/tars-agent-s1/dropped.txt', 'x')
            \\fs.write('/tmp/tars-agent-s1/e.txt', 'data')!
            \\
        , .{});
        const dropped_missing = if (std.Io.Dir.cwd().access(g_io, scratch ++ "/dropped.txt", .{})) |_| false else |_| true;
        check("3d. await하지 않고 버린 요청은 아무 일도 하지 않는다 (승인 우회 없음)", r5.code == c.CL_SUCCESS and dropped_missing and g_asked.items.len == 1 and g_asked.items[0] == 2, "code={s} 물은 요청 번호={any} dropped.txt 없음={}", .{ codeName(r5.code), g_asked.items, dropped_missing });

        // 스크립트가 직접 만든 Future
        const r6 = run(vm,
            \\r := FutureResolver.new(int)
            \\f := r.future()
            \\print(f.await())
            \\
        , .{});
        check("3e. 스크립트가 만든 미완료 Future(태그 0)는 버린다", (r6.code == c.CL_ERROR_INTERRUPT and g_abandoned_foreign) or r6.code == c.CL_ERROR_COMPILE, "code={s} foreign={} | {s}", .{ codeName(r6.code), g_abandoned_foreign, if (r6.code == c.CL_ERROR_COMPILE) firstLine(errorSummary(vm)) else "" });

        const live = c.cl_thread_count_objects(c.cl_vm_main_thread(vm));
        check("3f. 승인 흐름 뒤 살아 있는 객체 수", true, "live objects={d} (persist_main의 선언과 지역 변수가 남아 있을 수 있다)", .{live});
    }

    // 4. 동시 승인 (ADR 0016): scope 블록으로 요청 둘
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        const r = run(vm,
            \\use fs
            \\fn w(path str) -> !void:
            \\    fs.write(path, 'x')!
            \\fn both() -> !void:
            \\    scope |s|:
            \\        s.start(w, {'/tmp/tars-agent-s1/s1.txt'})
            \\        s.start(w, {'/tmp/tars-agent-s1/s2.txt'})
            \\try:
            \\    both()!
            \\    print('both done')
            \\else |e|:
            \\    print('failed %{e}')
            \\
        , .{});
        check("4. scope 블록의 요청 둘: 번호 순으로 하나씩 묻는다", r.code == c.CL_SUCCESS and g_asked.items.len == 2 and g_asked.items[0] == 1 and g_asked.items[1] == 2 and std.mem.indexOf(u8, g_out.items, "both done") != null, "code={s} awaits={d} 물은 순서={any} 출력={s} | {s}", .{ codeName(r.code), r.awaits, g_asked.items, std.mem.trim(u8, g_out.items, "\n"), if (r.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });

        const r2 = run(vm,
            \\use fs
            \\fn w(path str) -> !void:
            \\    fs.write(path, 'x')!
            \\fn both() -> !void:
            \\    scope |s|:
            \\        s.start(w, {'/etc/tars-denied-1'})
            \\        s.start(w, {'/tmp/tars-agent-s1/s3.txt'})
            \\try:
            \\    both()!
            \\    print('both done')
            \\else |e|:
            \\    print('failed %{e}')
            \\
        , .{ .deny_prefix = "/etc/" });
        const s3_missing = if (std.Io.Dir.cwd().access(g_io, scratch ++ "/s3.txt", .{})) |_| false else |_| true;
        var undone: usize = 0;
        for (g_reqs.items) |q| {
            if (!q.done) undone += 1;
        }
        check("4b. 하나를 거부하면 나머지 요청은 묻지 않은 채 버려진다", r2.code == c.CL_SUCCESS and g_asked.items.len == 1 and s3_missing and undone == 1, "code={s} 물은 순서={any} s3.txt 없음={} 완료 안 된 요청={d} 출력={s}", .{ codeName(r2.code), g_asked.items, s3_missing, undone, std.mem.trim(u8, g_out.items, "\n") });

        const r3 = run(vm,
            \\use fs
            \\fn w(path str) -> !void:
            \\    fs.write(path, 'x')!
            \\fn inner() -> !void:
            \\    scope |s|:
            \\        s.start(w, {'/tmp/tars-agent-s1/n2.txt'})
            \\        s.start(w, {'/tmp/tars-agent-s1/n3.txt'})
            \\fn outer() -> !void:
            \\    scope |s|:
            \\        s.start(w, {'/tmp/tars-agent-s1/n1.txt'})
            \\        s.start(inner, {})
            \\try:
            \\    outer()!
            \\    print('nested done')
            \\else |e|:
            \\    print('failed %{e}')
            \\
        , .{});
        check("4c. 중첩 scope 블록 (cyber F-111): 번호 순 완료로 끝까지 간다", r3.code == c.CL_SUCCESS and std.mem.indexOf(u8, g_out.items, "nested done") != null and g_asked.items.len == 3, "code={s} awaits={d} 물은 순서={any} | {s}", .{ codeName(r3.code), r3.awaits, g_asked.items, if (r3.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });
    }

    // 5. 상한 넷
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        _ = run(vm, "keep := 7\nfn helper() -> int:\n    return 11\n", .{});

        c.cl_vm_set_fuel(vm, 100_000);
        var t0 = nowMs();
        const r = run(vm, "n := 0\nwhile true:\n    n += 1\n", .{});
        check("5a. 연료(fuel): 무한 루프가 INTERRUPT로 끝난다", r.code == c.CL_ERROR_INTERRUPT, "code={s} {d}ms | {s}", .{ codeName(r.code), nowMs() - t0, firstLine(errorSummary(vm)) });
        c.cl_vm_set_fuel(vm, 0);

        const th = try std.Thread.spawn(.{}, timerThread, .{ vm, 200 });
        t0 = nowMs();
        const r2 = run(vm, "m := 0\nwhile true:\n    m += 1\n", .{});
        th.join();
        check("5b. 벽시계(wall-clock): 타이머 스레드의 cl_vm_interrupt", r2.code == c.CL_ERROR_INTERRUPT, "code={s} {d}ms 뒤 (타이머 200ms)", .{ codeName(r2.code), nowMs() - t0 });

        c.cl_vm_set_stack_limit(vm, 1 << 20);
        const r3 = run(vm, "fn rec(n int) -> int:\n    return rec(n + 1) + 1\nprint(rec(0))\n", .{});
        check("5c. 스택 상한: 폭주 재귀가 PANIC(Stack overflow)", r3.code == c.CL_ERROR_PANIC and std.mem.indexOf(u8, errorSummary(vm), "Stack overflow") != null, "code={s} | {s}", .{ codeName(r3.code), firstLine(errorSummary(vm)) });

        const before = c.cl_vm_memory_used(vm);
        c.cl_vm_set_memory_limit(vm, @intCast(before + 8 * 1024 * 1024));
        const r4 = run(vm, "xs := []int{}\nfor 0..1000000000 |i|:\n    xs += i\n", .{});
        const after = c.cl_vm_memory_used(vm);
        check("5d. 메모리 상한: 폭주 할당이 PANIC(OutOfMemory)", r4.code == c.CL_ERROR_PANIC and std.mem.indexOf(u8, errorSummary(vm), "OutOfMemory") != null, "code={s} VM 메모리 {d}KiB -> {d}KiB | {s}", .{ codeName(r4.code), before / 1024, after / 1024, firstLine(errorSummary(vm)) });
        c.cl_vm_set_memory_limit(vm, 0);

        const r5 = run(vm, "print(helper())\n", .{});
        const r6 = run(vm, "print(keep)\n", .{});
        check("5e. 상한에 걸린 뒤: 함수 선언은 남고 지역 변수는 사라진다", r5.code == c.CL_SUCCESS and r6.code == c.CL_ERROR_COMPILE, "helper()={s} keep={s} | {s}", .{ codeName(r5.code), codeName(r6.code), firstLine(errorSummary(vm)) });
    }

    // 6. persist_main과 validate
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        const r1 = run(vm, "use fs\ncount := 3\nfn twice(n int) -> int:\n    return n * 2\n", .{});
        const r2 = run(vm, "count += 1\nprint(twice(count))\n", .{});
        check("6a. persist_main: 변수, 함수, use가 다음 eval로 이어진다", r1.code == c.CL_SUCCESS and r2.code == c.CL_SUCCESS and std.mem.eql(u8, g_out.items, "8\n"), "출력={s}", .{std.mem.trim(u8, g_out.items, "\n")});

        const bad = "total := count + 1\nprint(totl)\n";
        const vcode = c.cl_vm_validate(vm, B(bad));
        var ce: c.CLCompileError = undefined;
        const has = c.cl_vm_compile_error(vm, &ce);
        const sum = c.cl_vm_compile_error_summary(vm);
        check("6b. validate: 세션의 변수를 보면서 컴파일만 하고 구조화된 오류를 준다", vcode == c.CL_ERROR_COMPILE and has and ce.has_loc and ce.line == 1, "kind={d} line={d} col={d} len={d} msg={s}", .{ ce.kind, ce.line, ce.col, ce.len, S(ce.msg) });
        std.debug.print("       요약 문자열:\n{s}\n", .{S(sum)});
        c.cl_vm_freeb(vm, sum);

        const vok = c.cl_vm_validate(vm, B("fn only_validated() -> int:\n    return 1\nprobe := 5\n"));
        const r3 = run(vm, "print(only_validated())\n", .{});
        const r4 = run(vm, "print(count)\n", .{});
        check("6c. validate한 선언은 넘어가지 않고 세션은 그대로다", vok == c.CL_SUCCESS and r3.code == c.CL_ERROR_COMPILE and r4.code == c.CL_SUCCESS, "validate={s} 검증만 한 함수 호출={s} count={s}", .{ codeName(vok), codeName(r3.code), std.mem.trim(u8, g_out.items, "\n") });

        const vraw = c.cl_vm_validate(vm, B("p := Ptr[int](0)\n"));
        const sraw = if (vraw != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "";
        check("6d. validate가 raw 포인터를 거부하는가 (설정 인자가 없다)", true, "validate={s} | {s}", .{ codeName(vraw), sraw });

        const t0 = nowMs();
        var i: usize = 0;
        while (i < 200) : (i += 1) _ = c.cl_vm_validate(vm, B("x := count * 2\nprint(twice(x))\n"));
        const tv = nowMs() - t0;
        const t1 = nowMs();
        i = 0;
        while (i < 200) : (i += 1) _ = run(vm, "print(twice(count))\n", .{});
        check("6e. 비용: validate와 eval 각 200회", true, "validate {d}ms, eval {d}ms (200회 합)", .{ tv, nowMs() - t1 });
    }

    // 7. 샌드박스 경계
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        g_denied_modules = 0;
        const r1 = run(vm, "use c\nprint(1)\n", .{});
        const s1 = firstLine(errorSummary(vm));
        check("7a. use c: 호스트 로더가 거부한다", r1.code == c.CL_ERROR_COMPILE and g_denied_modules == 1, "code={s} | {s}", .{ codeName(r1.code), s1 });
        const r2 = run(vm, "use os\nprint(os.cwd())\n", .{});
        check("7b. use os: 라이브러리에 없는 모듈", r2.code == c.CL_ERROR_COMPILE, "code={s} | {s}", .{ codeName(r2.code), firstLine(errorSummary(vm)) });
        const r3 = run(vm, "p := Ptr[int](0)\nprint(p.*)\n", .{});
        check("7c. deny_raw_ptrs: 스크립트의 raw 포인터는 컴파일 오류", r3.code == c.CL_ERROR_COMPILE, "code={s} | {s}", .{ codeName(r3.code), firstLine(errorSummary(vm)) });
        const r4 = run(vm, "use fs\nprint(fs.read('/tmp/tars-agent-s1/in.txt')!.len())\n", .{});
        check("7d. deny_raw_ptrs와 호스트 모듈 선언이 함께 동작한다", r4.code == c.CL_SUCCESS, "code={s} 출력={s} | {s}", .{ codeName(r4.code), std.mem.trim(u8, g_out.items, "\n"), if (r4.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });
        const r5 = run(vm, "x := @bitCast(int, 1.5)\nprint(x)\n", .{});
        check("7e. intrinsic(@bitCast)은 스크립트에서 못 쓴다", r5.code == c.CL_ERROR_COMPILE, "code={s} | {s}", .{ codeName(r5.code), firstLine(errorSummary(vm)) });
        const r6 = run(vm,
            \\fn work(n int) -> int:
            \\    return n * 2
            \\f := spawn(work, {21})
            \\print(f.await())
            \\
        , .{});
        check("7f. spawn: 지금은 막는 장치가 없다 (관찰)", true, "code={s} 출력={s} | {s}", .{ codeName(r6.code), std.mem.trim(u8, g_out.items, "\n"), if (r6.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });
        const r7 = run(vm, "use io\nprint(1)\n", .{});
        check("7g. use io: 기본 로더가 주는 모듈 (관찰)", true, "code={s} | {s}", .{ codeName(r7.code), if (r7.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "로드됨" });
    }

    // 8. #[bind]의 기본값 매개변수
    {
        const vm = newVm();
        defer c.cl_vm_deinit(vm);
        g_fs_default_param = true;
        const r = run(vm, "use fs\nprint(fs.peek('a'))\nprint(fs.peek('a', 5))\n", .{});
        g_fs_default_param = false;
        check("8. #[bind] 함수의 기본값 매개변수 (관찰)", true, "code={s} 출력={s} | {s}", .{ codeName(r.code), std.mem.trim(u8, g_out.items, "\n"), if (r.code != c.CL_SUCCESS) firstLine(errorSummary(vm)) else "" });
    }

    // 9. VM 비용
    {
        const t0 = nowMs();
        var vms: [20]?*c.CLVM = undefined;
        for (&vms) |*v| {
            v.* = newVm();
            _ = run(v.*, "use fs\nprint(1)\n", .{});
        }
        const dt = nowMs() - t0;
        const mem = c.cl_vm_memory_used(vms[0]);
        for (vms) |v| c.cl_vm_deinit(v);
        check("9. VM 20개 생성과 첫 eval", true, "{d}ms (개당 {d}ms), VM 하나가 쥔 메모리 {d}KiB", .{ dt, @divTrunc(dt, 20), mem / 1024 });
    }

    std.debug.print("\n합계: PASS {d}, FAIL {d}\n", .{ g_pass, g_fail });
    std.process.exit(if (g_fail == 0) 0 else 1);
}
