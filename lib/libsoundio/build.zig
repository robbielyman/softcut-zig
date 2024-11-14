const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const static = b.option(bool, "static", "build a static libsoundio") orelse true;

    const module = b.addModule("soundio", .{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (static) {
        const lib = try compileLibSoundio(b, target, optimize);
        b.installArtifact(lib);
        tests.linkLibrary(lib);
        module.linkLibrary(lib);
    } else {
        const t = target.result.os.tag;

        // homebrew doesn't provide pkg-config for libsoundio???
        if (t == .macos or t == .linux) {
            module.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
            tests.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
            module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        }

        module.linkSystemLibrary("soundio", .{
            .needed = true,
        });
        tests.linkSystemLibrary("soundio");

        switch (t) {
            .macos => {
                module.linkFramework("CoreAudio", .{
                    .needed = true,
                });
                module.linkFramework("CoreFoundation", .{
                    .needed = true,
                });
                tests.linkFramework("CoreAudio");
                tests.linkFramework("CoreFoundation");
                module.linkFramework("AudioUnit", .{
                    .needed = true,
                });
                tests.linkFramework("AudioUnit");
            },
            .linux => {
                module.linkSystemLibrary("asound", .{});
                module.linkSystemLibrary("pulseaudio", .{});
                module.linkSystemLibrary("jack", .{});
                tests.linkSystemLibrary("asound");
                tests.linkSystemLibrary("pulseaudio");
                tests.linkSystemLibrary("jack");
            },
            .windows => {
                module.linkSystemLibrary("WASAPI", .{});
                tests.linkSystemLibrary("WASAPI");
            },
            else => {},
        }
    }

    const tests_run_step = b.addRunArtifact(tests);
    const tests_step = b.step("test", "run the tests");
    tests_step.dependOn(&tests_run_step.step);
}

fn compileLibSoundio(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "soundio",
    });
    lib.linkLibC();

    const upstream = b.dependency("upstream", .{});
    b.installArtifact(lib);

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();

    try files.appendSlice(&.{
        "soundio.c",
        "util.c",
        "os.c",
        "dummy.c",
        "channel_layout.c",
        "ring_buffer.c",
    });

    const t = target.result.os.tag;

    switch (t) {
        .macos => try files.append("coreaudio.c"),
        .windows => try files.append("wasapi.c"),
        // FIXME: surely this is not the right way to do this
        .linux => try files.appendSlice(&.{
            "pulseaudio.c",
            "jack.c",
            "alsa.c",
        }),
        else => return error.NotSupported,
    }

    lib.addCSourceFiles(.{
        .root = .{ .dependency = .{
            .dependency = upstream,
            .sub_path = "src",
        } },
        .files = files.items,
        .flags = &.{},
    });
    const opts: std.Build.Step.ConfigHeader.Options = .{
        .style = .{ .cmake = .{ .dependency = .{
            .dependency = upstream,
            .sub_path = "src/config.h.in",
        } } },
        .include_path = "config.h",
    };
    const config = switch (t) {
        .macos => b.addConfigHeader(opts, macos_config),
        .windows => b.addConfigHeader(opts, windows_config),
        .linux => b.addConfigHeader(opts, linux_config),
        else => return error.NotSupported,
    };
    lib.addConfigHeader(config);
    lib.installConfigHeader(config);
    lib.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "",
    } });
    lib.installHeadersDirectory(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "soundio",
    } }, "soundio", .{});
    switch (t) {
        .macos => {
            lib.linkFramework("CoreAudio");
            lib.linkFramework("AudioUnit");
            lib.linkFramework("CoreFoundation");
        },
        .linux => {
            lib.linkSystemLibrary("asound");
            lib.linkSystemLibrary("pulseaudio");
            lib.linkSystemLibrary("jack");
        },
        .windows => {
            lib.linkSystemLibrary("WASAPI");
        },
        else => return error.NotSupported,
    }
    return lib;
}

const macos_config = .{
    .LIBSOUNDIO_VERSION_MAJOR = 2,
    .LIBSOUNDIO_VERSION_MINOR = 0,
    .LIBSOUNDIO_VERSION_PATCH = 0,
    .SOUNDIO_HAVE_JACK = 0,
    .SOUNDIO_HAVE_PULSEAUDIO = 0,
    .SOUNDIO_HAVE_ALSA = 0,
    .SOUNDIO_HAVE_COREAUDIO = 1,
    .SOUNDIO_HAVE_WASAPI = 0,
};
const windows_config = .{
    .LIBSOUNDIO_VERSION_MAJOR = 2,
    .LIBSOUNDIO_VERSION_MINOR = 0,
    .LIBSOUNDIO_VERSION_PATCH = 0,
    .SOUNDIO_HAVE_JACK = 0,
    .SOUNDIO_HAVE_PULSEAUDIO = 0,
    .SOUNDIO_HAVE_ALSA = 0,
    .SOUNDIO_HAVE_COREAUDIO = 0,
    .SOUNDIO_HAVE_WASAPI = 1,
};
const linux_config = .{
    .LIBSOUNDIO_VERSION_MAJOR = 2,
    .LIBSOUNDIO_VERSION_MINOR = 0,
    .LIBSOUNDIO_VERSION_PATCH = 0,
    .SOUNDIO_HAVE_JACK = 1,
    .SOUNDIO_HAVE_PULSEAUDIO = 1,
    .SOUNDIO_HAVE_ALSA = 1,
    .SOUNDIO_HAVE_COREAUDIO = 0,
    .SOUNDIO_HAVE_WASAPI = 0,
};
