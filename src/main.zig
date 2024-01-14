const std = @import("std");
const osc = @import("osc.zig");
const client = @import("client.zig");

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

    const softcut = try client.create(allocator);
    defer allocator.destroy(softcut);

    try softcut.setup();
    defer softcut.cleanup();
    try softcut.start();
    defer softcut.stop();

    try softcut.connectInputs();
    try softcut.connectOutputs();

    const interface = try osc.init(softcut);
    defer interface.deinit();

    try stdout.print("entering main loop...\n", .{});
    try bw.flush();
    while (!interface.quit) {
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    try stdout.print("SOFTCUT goodbye\n", .{});
    try bw.flush();
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
