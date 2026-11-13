// 스파이크 2: 제공자 층. 버리는 코드다.
// ADR 0015의 방향을 그대로 옮겨 본다:
//   - 코어가 보는 자체 메시지 모델 (Message, Block)
//   - 전송 형식마다 어댑터 (요청 만들기, 스트림 풀기)
//   - 제공자는 데이터 (기준 주소, 인증 헤더, 모델, 쓰는 형식)
const std = @import("std");

// ---------- 자체 메시지 모델 ----------

pub const Block = union(enum) {
    text: []const u8,
    // raw: 받은 형식의 어댑터만 해석하는 불투명 칸. Anthropic 형식에서는 signature다.
    thinking: struct { text: []const u8, raw: []const u8 },
    tool_call: struct { id: []const u8, name: []const u8, args_json: []const u8 },
    tool_result: struct { id: []const u8, content: []const u8, is_error: bool },
};
pub const Role = enum { user, assistant };
pub const Message = struct { role: Role, blocks: []const Block };

pub const Stop = enum { end, tool_use, max_tokens, other };
pub const Reply = struct {
    message: Message,
    stop: Stop, // 내용에서 다시 계산한 값
    stop_raw: []const u8, // 제공자가 준 값 그대로
    in_tokens: i64 = 0,
    out_tokens: i64 = 0,
    cached_tokens: i64 = 0,
    http_status: u16 = 0,
    error_body: []const u8 = "",
};

pub const Tool = struct { name: []const u8, description: []const u8, schema_json: []const u8 };

// ---------- 제공자는 데이터 ----------

pub const Format = enum { anthropic, openai };
pub const Auth = enum { x_api_key, bearer };
pub const Provider = struct {
    name: []const u8,
    format: Format,
    url: []const u8,
    auth: Auth,
    key_env: []const u8,
    model: []const u8,
};
pub const providers = [_]Provider{
    .{ .name = "ds-anth", .format = .anthropic, .url = "https://api.deepseek.com/anthropic/v1/messages", .auth = .x_api_key, .key_env = "DEEPSEEK_API_KEY", .model = "deepseek-chat" },
    .{ .name = "ds-oai", .format = .openai, .url = "https://api.deepseek.com/chat/completions", .auth = .bearer, .key_env = "DEEPSEEK_API_KEY", .model = "deepseek-chat" },
    .{ .name = "or-anth", .format = .anthropic, .url = "https://openrouter.ai/api/v1/messages", .auth = .bearer, .key_env = "OPENROUTER_API_KEY", .model = "qwen/qwen3.8-flash" },
    .{ .name = "or-oai", .format = .openai, .url = "https://openrouter.ai/api/v1/chat/completions", .auth = .bearer, .key_env = "OPENROUTER_API_KEY", .model = "qwen/qwen3.8-flash" },
};

// 스트리밍 중 프런트엔드에 흘리는 내부 이벤트.
pub const Event = union(enum) {
    text: []const u8,
    thinking: []const u8,
    tool_start: []const u8, // 도구 이름
    tool_args: []const u8, // 인자 JSON 조각
};
pub const Sink = *const fn (ev: Event) void;

// ---------- 어댑터 1: 요청 만들기 ----------

fn parseJson(arena: std.mem.Allocator, s: []const u8) std.json.Value {
    return std.json.parseFromSliceLeaky(std.json.Value, arena, s, .{}) catch .null;
}

pub fn buildBody(arena: std.mem.Allocator, p: Provider, model: []const u8, system: []const u8, tools: []const Tool, history: []const Message) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(arena);
    var js: std.json.Stringify = .{ .writer = &aw.writer };
    try js.beginObject();
    try js.objectField("model");
    try js.write(model);
    try js.objectField("max_tokens");
    try js.write(4096);
    try js.objectField("stream");
    try js.write(true);
    switch (p.format) {
        .anthropic => {
            try js.objectField("system");
            try js.write(system);
            try js.objectField("tools");
            try js.beginArray();
            for (tools) |t| {
                try js.beginObject();
                try js.objectField("name");
                try js.write(t.name);
                try js.objectField("description");
                try js.write(t.description);
                try js.objectField("input_schema");
                try js.write(parseJson(arena, t.schema_json));
                try js.endObject();
            }
            try js.endArray();
            try js.objectField("messages");
            try js.beginArray();
            for (history) |m| {
                try js.beginObject();
                try js.objectField("role");
                try js.write(@tagName(m.role));
                try js.objectField("content");
                try js.beginArray();
                for (m.blocks) |b| {
                    try js.beginObject();
                    switch (b) {
                        .text => |t| {
                            try js.objectField("type");
                            try js.write("text");
                            try js.objectField("text");
                            try js.write(t);
                        },
                        .thinking => |t| {
                            try js.objectField("type");
                            try js.write("thinking");
                            try js.objectField("thinking");
                            try js.write(t.text);
                            try js.objectField("signature");
                            try js.write(t.raw);
                        },
                        .tool_call => |t| {
                            try js.objectField("type");
                            try js.write("tool_use");
                            try js.objectField("id");
                            try js.write(t.id);
                            try js.objectField("name");
                            try js.write(t.name);
                            try js.objectField("input");
                            try js.write(parseJson(arena, t.args_json));
                        },
                        .tool_result => |t| {
                            try js.objectField("type");
                            try js.write("tool_result");
                            try js.objectField("tool_use_id");
                            try js.write(t.id);
                            try js.objectField("content");
                            try js.write(t.content);
                            try js.objectField("is_error");
                            try js.write(t.is_error);
                        },
                    }
                    try js.endObject();
                }
                try js.endArray();
                try js.endObject();
            }
            try js.endArray();
        },
        .openai => {
            try js.objectField("stream_options");
            try js.write(.{ .include_usage = true });
            try js.objectField("tools");
            try js.beginArray();
            for (tools) |t| {
                try js.beginObject();
                try js.objectField("type");
                try js.write("function");
                try js.objectField("function");
                try js.beginObject();
                try js.objectField("name");
                try js.write(t.name);
                try js.objectField("description");
                try js.write(t.description);
                try js.objectField("parameters");
                try js.write(parseJson(arena, t.schema_json));
                try js.endObject();
                try js.endObject();
            }
            try js.endArray();
            try js.objectField("messages");
            try js.beginArray();
            try js.write(.{ .role = "system", .content = system });
            for (history) |m| {
                // OpenAI 형식은 블록이 없다. tool_result는 role이 tool인 별도 메시지가 되고,
                // assistant의 text, thinking, tool_call은 메시지 하나의 필드 셋으로 흩어진다.
                var text: std.ArrayList(u8) = .empty;
                var thinking: std.ArrayList(u8) = .empty;
                var ncalls: usize = 0;
                for (m.blocks) |b| switch (b) {
                    .text => |t| try text.appendSlice(arena, t),
                    .thinking => |t| try thinking.appendSlice(arena, t.text),
                    .tool_call => ncalls += 1,
                    .tool_result => |t| try js.write(.{ .role = "tool", .tool_call_id = t.id, .content = t.content }),
                };
                if (m.role == .user and text.items.len == 0) continue;
                try js.beginObject();
                try js.objectField("role");
                try js.write(@tagName(m.role));
                try js.objectField("content");
                try js.write(text.items);
                if (m.role == .assistant and thinking.items.len > 0) {
                    try js.objectField("reasoning_content");
                    try js.write(thinking.items);
                }
                if (ncalls > 0) {
                    try js.objectField("tool_calls");
                    try js.beginArray();
                    for (m.blocks) |b| switch (b) {
                        .tool_call => |t| try js.write(.{ .id = t.id, .type = "function", .function = .{ .name = t.name, .arguments = t.args_json } }),
                        else => {},
                    };
                    try js.endArray();
                }
                try js.endObject();
            }
            try js.endArray();
        },
    }
    try js.endObject();
    return aw.written();
}

// ---------- 어댑터 2: 스트림 풀기 ----------

const Call = struct { id: []const u8 = "", name: []const u8 = "", args: std.ArrayList(u8) = .empty, index: i64 = -1 };

const Acc = struct {
    arena: std.mem.Allocator,
    sink: Sink,
    text: std.ArrayList(u8) = .empty,
    thinking: std.ArrayList(u8) = .empty,
    signature: std.ArrayList(u8) = .empty,
    calls: std.ArrayList(Call) = .empty,
    stop_raw: []const u8 = "",
    in_tokens: i64 = 0,
    out_tokens: i64 = 0,
    cached_tokens: i64 = 0,
    cur: enum { none, text, thinking, tool } = .none,

    fn str(v: ?std.json.Value) []const u8 {
        if (v) |x| if (x == .string) return x.string;
        return "";
    }
    fn int(v: ?std.json.Value) i64 {
        if (v) |x| if (x == .integer) return x.integer;
        return 0;
    }
    fn obj(v: ?std.json.Value, key: []const u8) ?std.json.Value {
        if (v) |x| if (x == .object) return x.object.get(key);
        return null;
    }

    fn onText(a: *Acc, s: []const u8) !void {
        if (s.len == 0) return;
        try a.text.appendSlice(a.arena, s);
        a.sink(.{ .text = s });
    }
    fn onThinking(a: *Acc, s: []const u8) !void {
        if (s.len == 0) return;
        try a.thinking.appendSlice(a.arena, s);
        a.sink(.{ .thinking = s });
    }

    fn anthropic(a: *Acc, d: std.json.Value) !void {
        const ty = str(obj(d, "type"));
        if (std.mem.eql(u8, ty, "message_start")) {
            const u = obj(obj(d, "message"), "usage");
            a.in_tokens = int(obj(u, "input_tokens"));
            a.cached_tokens = int(obj(u, "cache_read_input_tokens"));
        } else if (std.mem.eql(u8, ty, "content_block_start")) {
            const cb = obj(d, "content_block");
            const cty = str(obj(cb, "type"));
            if (std.mem.eql(u8, cty, "tool_use")) {
                a.cur = .tool;
                try a.calls.append(a.arena, .{ .id = try a.arena.dupe(u8, str(obj(cb, "id"))), .name = try a.arena.dupe(u8, str(obj(cb, "name"))) });
                a.sink(.{ .tool_start = a.calls.items[a.calls.items.len - 1].name });
            } else if (std.mem.eql(u8, cty, "thinking")) {
                a.cur = .thinking;
            } else a.cur = .text;
        } else if (std.mem.eql(u8, ty, "content_block_delta")) {
            const dl = obj(d, "delta");
            const dty = str(obj(dl, "type"));
            if (std.mem.eql(u8, dty, "text_delta")) {
                try a.onText(str(obj(dl, "text")));
            } else if (std.mem.eql(u8, dty, "thinking_delta")) {
                try a.onThinking(str(obj(dl, "thinking")));
            } else if (std.mem.eql(u8, dty, "signature_delta")) {
                try a.signature.appendSlice(a.arena, str(obj(dl, "signature")));
            } else if (std.mem.eql(u8, dty, "input_json_delta")) {
                const part = str(obj(dl, "partial_json"));
                if (a.calls.items.len > 0) try a.calls.items[a.calls.items.len - 1].args.appendSlice(a.arena, part);
                a.sink(.{ .tool_args = part });
            }
        } else if (std.mem.eql(u8, ty, "message_delta")) {
            a.stop_raw = try a.arena.dupe(u8, str(obj(obj(d, "delta"), "stop_reason")));
            const u = obj(d, "usage");
            a.out_tokens = int(obj(u, "output_tokens"));
            if (int(obj(u, "input_tokens")) > 0) a.in_tokens = int(obj(u, "input_tokens"));
        }
    }

    fn openai(a: *Acc, d: std.json.Value) !void {
        if (obj(d, "usage")) |u| if (u == .object) {
            a.in_tokens = int(obj(u, "prompt_tokens"));
            a.out_tokens = int(obj(u, "completion_tokens"));
            a.cached_tokens = int(obj(obj(u, "prompt_tokens_details"), "cached_tokens"));
        };
        const choices = obj(d, "choices") orelse return;
        if (choices != .array or choices.array.items.len == 0) return;
        const ch = choices.array.items[0];
        const fr = str(obj(ch, "finish_reason"));
        if (fr.len > 0) a.stop_raw = try a.arena.dupe(u8, fr);
        const dl = obj(ch, "delta");
        // 사고는 필드 이름이 제공자마다 다르다: DeepSeek은 reasoning_content, OpenRouter는 reasoning.
        try a.onThinking(str(obj(dl, "reasoning_content")));
        try a.onThinking(str(obj(dl, "reasoning")));
        try a.onText(str(obj(dl, "content")));
        if (obj(dl, "tool_calls")) |tcs| if (tcs == .array) for (tcs.array.items) |tc| {
            const idx = int(obj(tc, "index"));
            var cur_call: ?*Call = null;
            for (a.calls.items) |*c| if (c.index == idx) {
                cur_call = c;
            };
            const f = obj(tc, "function");
            if (cur_call == null) {
                try a.calls.append(a.arena, .{ .index = idx, .id = try a.arena.dupe(u8, str(obj(tc, "id"))), .name = try a.arena.dupe(u8, str(obj(f, "name"))) });
                cur_call = &a.calls.items[a.calls.items.len - 1];
                a.sink(.{ .tool_start = cur_call.?.name });
            }
            const part = str(obj(f, "arguments"));
            try cur_call.?.args.appendSlice(a.arena, part);
            if (part.len > 0) a.sink(.{ .tool_args = part });
        };
    }
};

// ---------- HTTP: std.http로 스트리밍 요청 ----------

pub var raw_log: ?*std.Io.Writer = null; // 원문 SSE를 남긴다

pub fn call(arena: std.mem.Allocator, io: std.Io, client: *std.http.Client, p: Provider, key: []const u8, body: []u8, sink: Sink) !Reply {
    const uri = try std.Uri.parse(p.url);
    const bearer = try std.fmt.allocPrint(arena, "Bearer {s}", .{key});
    var extra: [2]std.http.Header = undefined;
    var n_extra: usize = 0;
    if (p.format == .anthropic) {
        extra[n_extra] = .{ .name = "anthropic-version", .value = "2023-06-01" };
        n_extra += 1;
    }
    if (p.auth == .x_api_key) {
        extra[n_extra] = .{ .name = "x-api-key", .value = key };
        n_extra += 1;
    }
    var req = try client.request(.POST, uri, .{
        .keep_alive = false,
        .headers = .{
            .content_type = .{ .override = "application/json" },
            .accept_encoding = .{ .override = "identity" },
            .authorization = if (p.auth == .bearer) .{ .override = bearer } else .default,
        },
        .extra_headers = extra[0..n_extra],
    });
    defer req.deinit();
    try req.sendBodyComplete(body);
    var redirect_buf: [1024]u8 = undefined;
    var resp = try req.receiveHead(&redirect_buf);
    const status: u16 = @intCast(@intFromEnum(resp.head.status));
    const transfer = try arena.alloc(u8, 1 << 20); // 한 줄(SSE data)이 들어갈 만큼
    const rd = resp.reader(transfer);
    _ = io;

    var acc: Acc = .{ .arena = arena, .sink = sink };
    var err_body: std.ArrayList(u8) = .empty;
    while (true) {
        const line_opt = rd.takeDelimiter('\n') catch |e| switch (e) {
            error.StreamTooLong => return error.SseLineTooLong,
            else => break, // 연결이 끊겼다
        };
        const line0 = line_opt orelse break;
        const line = std.mem.trimEnd(u8, line0, "\r");
        if (raw_log) |w| {
            w.writeAll(line) catch {};
            w.writeByte('\n') catch {};
        }
        if (status != 200) {
            try err_body.appendSlice(arena, line);
            continue;
        }
        if (!std.mem.startsWith(u8, line, "data:")) continue; // event:, 주석(:), 빈 줄
        const data = std.mem.trim(u8, line[5..], " ");
        if (std.mem.eql(u8, data, "[DONE]")) break;
        const d = std.json.parseFromSliceLeaky(std.json.Value, arena, data, .{}) catch continue;
        switch (p.format) {
            .anthropic => try acc.anthropic(d),
            .openai => try acc.openai(d),
        }
    }

    // 블록 목록으로 조립: thinking, text, tool_call 순.
    var blocks: std.ArrayList(Block) = .empty;
    if (acc.thinking.items.len > 0 or acc.signature.items.len > 0)
        try blocks.append(arena, .{ .thinking = .{ .text = acc.thinking.items, .raw = acc.signature.items } });
    if (acc.text.items.len > 0) try blocks.append(arena, .{ .text = acc.text.items });
    for (acc.calls.items) |cl| try blocks.append(arena, .{ .tool_call = .{ .id = cl.id, .name = cl.name, .args_json = if (cl.args.items.len == 0) "{}" else cl.args.items } });

    // 끝난 이유는 제공자의 필드를 믿지 않고 내용에서 다시 계산한다.
    const stop: Stop = if (acc.calls.items.len > 0) .tool_use else if (std.mem.eql(u8, acc.stop_raw, "max_tokens") or std.mem.eql(u8, acc.stop_raw, "length")) .max_tokens else if (std.mem.eql(u8, acc.stop_raw, "end_turn") or std.mem.eql(u8, acc.stop_raw, "stop")) .end else .other;
    return .{
        .message = .{ .role = .assistant, .blocks = blocks.items },
        .stop = stop,
        .stop_raw = acc.stop_raw,
        .in_tokens = acc.in_tokens,
        .out_tokens = acc.out_tokens,
        .cached_tokens = acc.cached_tokens,
        .http_status = status,
        .error_body = err_body.items,
    };
}
