const std = @import("std");
const Translator = @import("translate_c").Translator;

// 스파이크 1: cyber를 build.zig.zon 의존으로 받아 정적 링크한다.
// 라이브러리는 의존의 아티팩트로 받고, cyber.h는 그 아티팩트의 include 경로로 따라온다.
// cyber.h의 Zig 바인딩은 translate-c 패키지로 만든다(본체는 손으로 쓴 extern을 추천한다).
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cyber = b.dependency("cyber", .{
        .target = target,
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
        .static = true,
        .dev = false,
        .build = @as([]const u8, "883"),
        .commit = @as([]const u8, "097b831"),
    });
    const cyber_lib = cyber.artifact("cyber");

    const exe = b.addExecutable(.{
        .name = "s1",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.linkLibrary(cyber_lib);
    exe.root_module.addCSourceFile(.{ .file = b.path("src/inc_check.c") });
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
