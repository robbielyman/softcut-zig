const std = @import("std");
const osc = @import("osc.zig");
const client = @import("client.zig");
const soundio = @import("soundio.zig");

const num_voices = @import("options").voices;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("SOFTCUT\nnumber of voices: {d}\n", .{num_voices});
    try bw.flush();

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const in_index, const out_index, const port = parseArgs(allocator) catch |err| {
        if (err == error.BadArgs) {
            try stdout.print("SOFTCUT usage:\nsoftcut-client -i [device_number] -o [device_number] -p [port=9999]\n", .{});
            try bw.flush();
            std.process.exit(0);
        } else return err;
    };
    defer {
        if (port) |p| allocator.free(p);
    }

    const softcut = try client.create(allocator);
    defer allocator.destroy(softcut);
    defer softcut.destroy();

    const audio = soundio.setup(allocator, softcut, in_index, out_index) catch |err| {
        if (err == error.NoDevicesGiven) {
            try stdout.print("SOFTCUT usage:\nsoftcut-client -i [device_number] -o [device_number] -p [port=9999]\n", .{});
            try bw.flush();
            std.process.exit(0);
        } else if (err == error.BadSampleRate) {
            try stdout.print("SOFTCUT requires 48kHz sample rate!", .{});
            try bw.flush();
            std.process.exit(1);
        } else return err;
    };
    defer allocator.destroy(audio);
    defer audio.teardown();

    var interface = try osc.init(allocator, softcut, port orelse "9999");
    defer allocator.destroy(interface);
    defer interface.deinit();

    try interface.printServerMethods();

    try stdout.print("entering main loop...\n", .{});
    try bw.flush();

    try audio.start();
    while (!interface.quit) {
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    try stdout.print("SOFTCUT goodbye\n", .{});
    try bw.flush();
}

fn parseArgs(allocator: std.mem.Allocator) !struct {?usize, ?usize, ?[:0]const u8} {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    var in_index: ?usize = null;
    var out_index: ?usize = null;
    var port: ?[:0]const u8 = null;
    while (args.next()) |arg| {
        if (arg[0] != '-' or arg.len != 2) return error.BadArgs;
        switch (arg[1]) {
            'i' => in_index = std.fmt.parseUnsigned(usize, args.next() orelse return error.BadArgs, 10) catch return error.BadArgs,
            'o' => out_index = std.fmt.parseUnsigned(usize, args.next() orelse return error.BadArgs, 10) catch return error.BadArgs,
            'p' => {
                port = try allocator.dupeZ(u8, args.next() orelse return error.BadArgs);
                _ = std.fmt.parseUnsigned(usize, port.?, 10) catch return error.BadArgs;
            },
            else => return error.BadArgs,
        }
    }
    return .{ in_index, out_index, port };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
