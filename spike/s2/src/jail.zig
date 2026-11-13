// 스파이크 2: 모델이 쓴 명령을 가두어 실행한다. 버리는 코드다.
// macOS에서는 sandbox-exec로 네트워크를 막고, 쓰기를 작업 폴더(/tmp/tars-agent-s2) 안으로 제한하고,
// 사용자 폴더(/Users, /Volumes) 읽기를 막는다. 읽은 것은 도구 결과로 모델 제공자에게 가기 때문이다.
// 명령마다 20초 상한을 둔다(perl의 alarm). 모델이 find / 같은 명령을 쓴 적이 있다.
// 본체에서는 이 자리가 권한 게이트(승인)와 Landlock이다 (명세 05).
const std = @import("std");
const builtin = @import("builtin");

pub const work_dir = "/tmp/tars-agent-s2";
const profile =
    \\(version 1)
    \\(allow default)
    \\(deny network*)
    \\(deny file-read* (subpath "/Users") (subpath "/Volumes"))
    \\(deny file-write*)
    \\(allow file-write* (subpath "/private/tmp/tars-agent-s2") (subpath "/tmp/tars-agent-s2") (literal "/dev/null") (literal "/dev/tty"))
;

pub fn sh(gpa: std.mem.Allocator, io: std.Io, cmd: []const u8) !std.process.RunResult {
    const argv: []const []const u8 = if (builtin.os.tag == .macos)
        &.{ "/usr/bin/sandbox-exec", "-p", profile, "/usr/bin/perl", "-e", "alarm 20; exec @ARGV", "/bin/sh", "-c", cmd }
    else
        &.{ "/bin/sh", "-c", cmd }; // 리눅스(tars 게스트)에서는 가두지 않는다. 스파이크는 버리는 VM 안에서만 돌린다.
    return std.process.run(gpa, io, .{ .argv = argv, .cwd = .{ .path = work_dir }, .stdout_limit = .limited(1 << 20), .stderr_limit = .limited(1 << 20) });
}

// fs.write가 쓸 수 있는 경로인가.
pub fn writable(path: []const u8) bool {
    if (std.mem.indexOf(u8, path, "..") != null) return false;
    return std.mem.startsWith(u8, path, work_dir ++ "/") or !std.mem.startsWith(u8, path, "/");
}
