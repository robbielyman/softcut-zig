const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const opts = b.addOptions();

    const voices = b.option(usize, "voices", "number of softcut voices");
    opts.addOption(usize, "voices", voices orelse 6);
    const static = b.option(bool, "static", "compile a static executable") orelse false;

    // dependencies

    const liblo = b.dependency("liblo", .{
        .target = target,
        .optimize = optimize,
        .static = static,
    });
    const libsoundio = b.dependency("libsoundio", .{
        .target = target,
        .optimize = optimize,
        .static = static,
    });
    const libsndfile = b.dependency("libsndfile", .{
        .target = target,
        .optimize = optimize,
        // .static = static,
    });

    // softcut

    const module = b.addModule("softcut", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("lib/softcut/softcut.zig"),
    });

    const lib = b.addStaticLibrary(.{
        .link_libc = true,
        .name = "softcut",
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const upstream = b.dependency("upstream", .{});

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();
    try files.appendSlice(&.{
        "FadeCurves.cpp",
        "ReadWriteHead.cpp",
        "SubHead.cpp",
        "Svf.cpp",
        "Voice.cpp",
    });
    module.linkLibrary(lib);

    lib.addCSourceFiles(.{
        .root = .{ .dependency = .{
            .dependency = upstream,
            .sub_path = "softcut-lib/src",
        } },
        .files = files.items,
    });
    lib.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "softcut-lib/include",
    } });
    lib.addCSourceFile(.{
        .file = b.path("lib/softcut/softcut_c.cpp"),
    });
    lib.addIncludePath(b.path("lib/softcut/include"));
    lib.installHeadersDirectory(b.path("lib/softcut/include"), "", .{});

    lib.linkLibCpp();

    // softcut-client

    const exe = b.addExecutable(.{
        .name = "softcut-client",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    exe.linkLibrary(lib);
    exe.root_module.addImport("softcut", module);
    exe.root_module.addImport("liblo", liblo.module("liblo"));
    exe.root_module.addImport("libsoundio", libsoundio.module("soundio"));
    exe.root_module.addImport("libsndfile", libsndfile.module("sndfile"));
    exe.root_module.addOptions("options", opts);

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.addArgs(b.args orelse &.{});
    run.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "run softcut-client");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{ .root_source_file = b.path("src/main.zig") });
    tests.linkLibrary(lib);

    tests.root_module.addImport("softcut", module);
    tests.root_module.addImport("liblo", liblo.module("liblo"));
    tests.root_module.addImport("libsoundio", libsoundio.module("soundio"));
    tests.root_module.addImport("libsndfile", libsndfile.module("sndfile"));
    tests.root_module.addOptions("options", opts);

    const tests_step = b.step("test", "run the tests");
    tests_step.dependOn(&tests.step);
}
