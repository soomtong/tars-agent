// 스파이크 2: 가장 작은 에이전트 루프. 버리는 코드다.
//
//   s2 [--provider ds-anth|ds-oai|or-anth|or-oai] [--model M] [--mode direct|codeact] [--guide PATH] "질문"
//
// 루프는 이것이 전부다:
//   1. 히스토리 전체를 모델에 보낸다 (모델은 상태가 없다)
//   2. 응답에 도구 호출이 없으면 끝
//   3. 있으면 호스트가 실행하고, 결과를 히스토리에 덧붙이고, 1로
// direct 모드의 도구는 sh(셸 명령) 하나, codeact 모드의 도구는 run(Cyber 스크립트) 하나다.
const std = @import("std");
const pv = @import("provider.zig");
const vm = @import("vm.zig");
const jail = @import("jail.zig");

var g_stderr: *std.Io.Writer = undefined;
fn out(comptime fmt: []const u8, args: anytype) void {
    g_stderr.print(fmt, args) catch {};
    g_stderr.flush() catch {};
}

fn traceLine(line: []const u8) void {
    out("{s}", .{line});
}

var g_stream_state: enum { none, text, thinking, tool } = .none;
fn sink(ev: pv.Event) void {
    switch (ev) {
        .thinking => |s| {
            if (g_stream_state != .thinking) out("\n  [사고] ", .{});
            g_stream_state = .thinking;
            out("{s}", .{s});
        },
        .text => |s| {
            if (g_stream_state != .text) out("\n  [글] ", .{});
            g_stream_state = .text;
            out("{s}", .{s});
        },
        .tool_start => |name| {
            out("\n  [도구 호출] {s} 인자(조각으로 온다): ", .{name});
            g_stream_state = .tool;
        },
        .tool_args => |s| out("{s}", .{s}),
    }
}

const direct_system =
    \\You are a coding agent working in a terminal. Act only through the `sh` tool: it runs a shell command and returns its output. Commands run in the working directory /tmp/tars-agent-s2; writes outside it and network access are blocked.
    \\Take small steps, check results, and when the task is done answer the user briefly in plain text.
;
const codeact_system_head =
    \\You are a coding agent working in a terminal. Act only through the `run` tool: it executes a Cyber script and returns what the script printed.
    \\Cyber is not Python. Read the guide below before writing code. A script that does not compile is not executed; you get the compiler error back and must fix it.
    \\Variables, functions and imports persist between `run` calls. The modules `fs` and `proc` are already imported.
    \\
    \\Capabilities (the only way to reach the outside world):
    \\- fs.read(path str) -> !str        read a whole file
    \\- fs.write(path str, text str) -> !void   write a whole file
    \\- proc.exec(cmd str) -> !str       run a shell command with /bin/sh -c, returns stdout and stderr
    \\The working directory is /tmp/tars-agent-s2. Writes outside it and network access are blocked. Use relative paths for files you create.
    \\Each returns an error union: use `x := fs.read(p)!` inside a `try:` block at top level, or `fs.read(p) !else 'default'`.
    \\Print what you need to see with print(). Do several things in one script when you can. When the task is done answer the user briefly in plain text.
    \\
    \\
;

fn argsField(arena: std.mem.Allocator, args_json: []const u8, field: []const u8) ?[]const u8 {
    const v = std.json.parseFromSliceLeaky(std.json.Value, arena, args_json, .{}) catch return null;
    if (v != .object) return null;
    const f = v.object.get(field) orelse return null;
    if (f != .string) return null;
    return f.string;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    var errbuf: [4096]u8 = undefined;
    var ew: std.Io.File.Writer = .init(.stderr(), io, &errbuf);
    g_stderr = &ew.interface;

    var provider = pv.providers[0];
    var model: ?[]const u8 = null;
    var mode: enum { direct, codeact } = .direct;
    var guide_path: []const u8 = "../../prompt/cyber-subset.en.md";
    var log_path: ?[]const u8 = null;
    var prompt: []const u8 = "";
    const args = try init.minimal.args.toSlice(arena);
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--provider")) {
            i += 1;
            for (pv.providers) |p| if (std.mem.eql(u8, p.name, args[i])) {
                provider = p;
            };
        } else if (std.mem.eql(u8, a, "--model")) {
            i += 1;
            model = args[i];
        } else if (std.mem.eql(u8, a, "--mode")) {
            i += 1;
            mode = if (std.mem.eql(u8, args[i], "codeact")) .codeact else .direct;
        } else if (std.mem.eql(u8, a, "--guide")) {
            i += 1;
            guide_path = args[i];
        } else if (std.mem.eql(u8, a, "--log")) {
            i += 1;
            log_path = args[i];
        } else prompt = a;
    }
    const model_name = model orelse provider.model;
    const key = init.environ_map.get(provider.key_env) orelse {
        out("환경 변수 {s}가 없다\n", .{provider.key_env});
        return;
    };

    var log_buf: [8192]u8 = undefined;
    var log_file: ?std.Io.File = null;
    var log_writer: std.Io.File.Writer = undefined;
    if (log_path) |lp| {
        log_file = try std.Io.Dir.cwd().createFile(io, lp, .{});
        log_writer = .init(log_file.?, io, &log_buf);
        pv.raw_log = &log_writer.interface;
    }

    var system: []const u8 = direct_system;
    var tools: []const pv.Tool = &.{.{ .name = "sh", .description = "Run a shell command and return its output", .schema_json = "{\"type\":\"object\",\"properties\":{\"cmd\":{\"type\":\"string\"}},\"required\":[\"cmd\"]}" }};
    if (mode == .codeact) {
        const guide = try std.Io.Dir.cwd().readFileAlloc(io, guide_path, arena, .limited(1 << 20));
        system = try std.mem.concat(arena, u8, &.{ codeact_system_head, guide });
        tools = &.{.{ .name = "run", .description = "Execute a Cyber script. Returns what it printed, or the compile error or panic.", .schema_json = "{\"type\":\"object\",\"properties\":{\"code\":{\"type\":\"string\"}},\"required\":[\"code\"]}" }};
        vm.trace = traceLine;
        vm.init(init.gpa, io);
    }

    std.Io.Dir.cwd().createDirPath(io, jail.work_dir) catch {};
    out("작업 폴더 {s} (명령은 이 안에서 돌고, 쓰기는 이 안으로 제한, 네트워크 차단)\n", .{jail.work_dir});
    var client: std.http.Client = .{ .allocator = init.gpa, .io = io };
    defer client.deinit();

    out("제공자 {s} | 형식 {s} | 모델 {s} | 모드 {s} | 시스템 프롬프트 {d}바이트\n", .{ provider.name, @tagName(provider.format), model_name, @tagName(mode), system.len });
    out("[사용자] {s}\n", .{prompt});

    var history: std.ArrayList(pv.Message) = .empty;
    const first = try arena.alloc(pv.Block, 1);
    first[0] = .{ .text = prompt };
    try history.append(arena, .{ .role = .user, .blocks = first });

    var total_in: i64 = 0;
    var total_out: i64 = 0;
    var total_cached: i64 = 0;
    var tool_errors: usize = 0;
    var tool_calls: usize = 0;
    const t_start = std.Io.Timestamp.now(io, .awake).toMilliseconds();

    var step: usize = 1;
    while (step <= 15) : (step += 1) {
        const body = try pv.buildBody(arena, provider, model_name, system, tools, history.items);
        out("\n--- 스텝 {d}: 요청 {d}바이트 (메시지 {d}개) ", .{ step, body.len, history.items.len });
        if (pv.raw_log) |w| w.print("\n>>> REQUEST step {d}\n{s}\n<<< RESPONSE\n", .{ step, body }) catch {};
        g_stream_state = .none;
        const t0 = std.Io.Timestamp.now(io, .awake).toMilliseconds();
        const reply = pv.call(arena, io, &client, provider, key, body, sink) catch |e| {
            out("\n요청 실패: {s}\n", .{@errorName(e)});
            break;
        };
        const dt = std.Io.Timestamp.now(io, .awake).toMilliseconds() - t0;
        if (reply.http_status != 200) {
            out("\nHTTP {d}: {s}\n", .{ reply.http_status, reply.error_body });
            break;
        }
        total_in += reply.in_tokens;
        total_out += reply.out_tokens;
        total_cached += reply.cached_tokens;
        out("\n  [끝] stop={s} (제공자 값 \"{s}\") 입력 {d} 토큰(캐시 {d}), 출력 {d} 토큰, {d}ms\n", .{ @tagName(reply.stop), reply.stop_raw, reply.in_tokens, reply.cached_tokens, reply.out_tokens, dt });

        // assistant 응답을 히스토리에 그대로 덧붙인다.
        try history.append(arena, reply.message);
        if (reply.stop != .tool_use) break;

        // 도구 호출을 차례로 실행하고, 결과를 user 메시지 하나에 모은다.
        var results: std.ArrayList(pv.Block) = .empty;
        for (reply.message.blocks) |b| switch (b) {
            .tool_call => |tc| {
                tool_calls += 1;
                var text: []const u8 = "";
                var is_error = false;
                if (mode == .direct) {
                    const cmd = argsField(arena, tc.args_json, "cmd") orelse "";
                    if (cmd.len == 0) {
                        text = "error: the tool input must be {\"cmd\": string}";
                        is_error = true;
                    } else {
                        const r = jail.sh(arena, io, cmd) catch |e| {
                            out("실행 실패 {s}\n", .{@errorName(e)});
                            break;
                        };
                        const code: i64 = switch (r.term) {
                            .exited => |cd| cd,
                            else => -1,
                        };
                        const merged = try std.mem.concat(arena, u8, &.{ r.stdout, r.stderr });
                        text = try std.fmt.allocPrint(arena, "{s}{s}", .{ merged[0..@min(merged.len, 6000)], if (code != 0) try std.fmt.allocPrint(arena, "\n(exit code {d})", .{code}) else "" });
                        is_error = code != 0;
                        if (text.len == 0) text = "(no output)";
                    }
                } else {
                    const code = argsField(arena, tc.args_json, "code") orelse "";
                    if (code.len == 0) {
                        text = "error: the tool input must be {\"code\": string}";
                        is_error = true;
                    } else {
                        const r = vm.runCode(code);
                        text = r.text;
                        is_error = r.is_error;
                        out("    [실행] 종류={s} 능력 호출 {d}회\n", .{ r.kind, r.calls });
                    }
                }
                if (is_error) tool_errors += 1;
                out("  [도구 결과{s}] {s}\n", .{ if (is_error) " (오류)" else "", std.mem.trimEnd(u8, text[0..@min(text.len, 700)], "\n") });
                try results.append(arena, .{ .tool_result = .{ .id = tc.id, .content = text, .is_error = is_error } });
            },
            else => {},
        };
        try history.append(arena, .{ .role = .user, .blocks = results.items });
    }
    const total_ms = std.Io.Timestamp.now(io, .awake).toMilliseconds() - t_start;
    if (mode == .codeact and vm.compiler_crashes > 0) out("\n(컴파일러가 자식 프로세스에서 {d}번 죽었다. 부모는 살아 있다)\n", .{vm.compiler_crashes});
    out("\n=== 요약: 스텝 {d}, 도구 호출 {d}(오류 {d}), 입력 {d} 토큰(캐시 {d}), 출력 {d} 토큰, {d}ms\n", .{ @min(step, 15), tool_calls, tool_errors, total_in, total_cached, total_out, total_ms });
    if (pv.raw_log) |w| w.flush() catch {};
    // 기계가 읽는 한 줄 (비교 표를 만들 때 쓴다)
    var obuf: [512]u8 = undefined;
    var ow: std.Io.File.Writer = .init(.stdout(), io, &obuf);
    ow.interface.print("{s}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{ provider.name, model_name, @tagName(mode), @min(step, 15), tool_calls, tool_errors, total_in, total_cached, total_out, total_ms }) catch {};
    ow.interface.flush() catch {};
    std.process.exit(0);
}
