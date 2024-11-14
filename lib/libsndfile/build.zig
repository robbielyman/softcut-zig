const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // TODO enable building statically?

    const module = b.addModule("sndfile", .{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    module.linkSystemLibrary("sndfile", .{
        .needed = true,
    });
    tests.linkSystemLibrary("sndfile");

    const tests_run_step = b.addRunArtifact(tests);
    const tests_step = b.step("test", "run the tests");
    tests_step.dependOn(&tests_run_step.step);
}
