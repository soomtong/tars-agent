const std = @import("std");
const Translator = @import("translate_c").Translator;

// 스파이크 2: 최소 에이전트 루프. cyber를 build.zig.zon 의존으로 받아 정적 링크한다.
// cyber 0.4.9의 build.zig는 라이브러리 아티팩트를 내보내지 않는다(artifact("cyber")가 실패).
// 그래서 받은 패키지 안에서 `zig build lib`를 한 번 더 돌려 libcyber.a를 얻는다.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cyber = b.dependency("cyber", .{});

    const triple = target.result.zigTriple(b.allocator) catch @panic("OOM");
    const lib_cmd = b.addSystemCommand(&.{
        b.graph.zig_exe,      "build",        "lib",
        "-Doptimize=ReleaseFast", "-Dffi=false", "-Dstatic=true",
    });
    lib_cmd.addArg(b.fmt("-Dtarget={s}", .{triple}));
    lib_cmd.setCwd(cyber.path("."));
    lib_cmd.addArg("--prefix");
    const lib_out = lib_cmd.addOutputDirectoryArg("cyber-out");
    lib_cmd.addArg("--cache-dir");
    _ = lib_cmd.addOutputDirectoryArg("cyber-cache");

    const exe = b.addExecutable(.{
        .name = "s2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addObjectFile(lib_out.path(b, "lib/libcyber.a"));
    const cy_c: Translator = .init(b.dependency("translate_c", .{}), .{
        .c_source_file = cyber.path("src/include/cyber.h"),
        .target = target,
        .optimize = optimize,
        .default_init = true,
    });
    exe.root_module.addImport("cyber_c", cy_c.mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.addPassthruArgs();
    b.step("run", "Run").dependOn(&run_cmd.step);
}
