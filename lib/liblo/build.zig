const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const static = b.option(bool, "static", "build a static liblo") orelse true;

    const module = b.addModule("liblo", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "main.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (static) {
        const lib = compileLibLo(b, target, optimize);

        b.installArtifact(lib);
        module.linkLibrary(lib);
        tests.linkLibrary(lib);
    } else {
        module.linkSystemLibrary("liblo", .{
            .needed = true,
        });
        tests.linkSystemLibrary("liblo");
    }

    const test_run_step = b.addRunArtifact(tests);
    const tests_step = b.step("test", "run the tests");
    tests_step.dependOn(&test_run_step.step);
}

fn compileLibLo(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "lo",
    });
    lib.linkLibC();

    const t = target.result;

    if (t.os.tag == .linux) {
        lib.defineCMacro("_BSD_SOURCE", "1");
    }

    const upstream = b.dependency("upstream", .{});

    const config = b.addConfigHeader(.{
        .style = .{
            .cmake = .{
                .dependency = .{
                    .dependency = upstream,
                    .sub_path = "cmake/config.h.in",
                },
            },
        },
        .include_path = "config.h",
    }, config_values);
    lib.addConfigHeader(config);
    lib.installConfigHeader(config, .{});

    const lo = b.addConfigHeader(.{
        .style = .{
            .cmake = .{
                .dependency = .{
                    .dependency = upstream,
                    .sub_path = "lo/lo.h.in",
                },
            },
        },
        .include_path = "lo/lo.h",
    }, .{ .THREADS_INCLUDE = "#include \"lo/lo_serverthread.h\"" });
    lib.addConfigHeader(lo);
    lib.installConfigHeader(lo, .{});

    const lo_endian = b.addConfigHeader(.{
        .style = .{
            .cmake = .{
                .dependency = .{
                    .dependency = upstream,
                    .sub_path = "lo/lo_endian.h.in",
                },
            },
        },
        .include_path = "lo/lo_endian.h",
    }, .{ .LO_BIGENDIAN = 2 });
    lib.addConfigHeader(lo_endian);
    lib.installConfigHeader(lo_endian, .{});

    lib.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = ".",
    } });
    lib.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "src",
    } });
    lib.defineCMacro("HAVE_CONFIG_H", "1");
    lib.addCSourceFiles(.{
        .dependency = upstream,
        .files = &library_sources,
        .flags = &.{"-std=c11"},
    });
    lib.installHeadersDirectoryOptions(.{
        .source_dir = .{
            .dependency = .{
                .dependency = upstream,
                .sub_path = "lo",
            },
        },
        .install_dir = .header,
        .install_subdir = "lo",
    });

    return lib;
}

// TODO: actually detect these things? seems mildly silly tho...
const config_values = .{
    .PACKAGE_NAME = "liblo",
    .PACKAGE_VERSION = "0.31",
    .LO_SO_VERSION = "{11, 1, 4}",
    .HAVE_POLL = 1,
    .HAVE_SELECT = 1,
    .HAVE_GETIFADDRS = 1,
    .HAVE_INET_PTON = 1,
    .HAVE_LIBPTHREAD = 1,
    .ENABLE_THREADS = 1,
    .PRINTF_LL = "ll",
};

const library_sources = .{
    "src/address.c",
    "src/blob.c",
    "src/bundle.c",
    "src/message.c",
    "src/method.c",
    "src/pattern_match.c",
    "src/send.c",
    "src/server.c",
    "src/timetag.c",
    "src/version.c",
    "src/server_thread.c",
};
