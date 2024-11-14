const std = @import("std");
const logger = std.log.scoped(.poll);

const This = @This();

name: [:0]const u8,
pid: ?std.Thread,
callback: ?*const fn ([:0]const u8, *anyopaque) void,
ctx: *anyopaque,
period_ms: std.atomic.Value(u64),
should_stop: std.atomic.Value(bool),

pub fn create(allocator: std.mem.Allocator, name: [:0]const u8) !*This {
    const ret = try allocator.create(This);
    ret.* = .{
        .name = name,
        .pid = null,
        .callback = null,
        .should_stop = std.atomic.Value(bool).init(true),
        .period_ms = std.atomic.Value(u64).init(1),
        .ctx = undefined,
    };
    return ret;
}

pub fn start(self: *This) void {
    self.should_stop.store(false, .seq_cst);
    if (self.pid != null)
        return
    else
        self.pid = std.Thread.spawn(.{}, loop, .{self}) catch blk: {
            logger.err("unable to spawn thread! polling will not work...", .{});
            break :blk null;
        };
}

pub fn stop(self: *This) void {
    self.should_stop.store(true, .seq_cst);
    if (self.pid) |thread| thread.detach();
}

pub fn kill(self: *This) void {
    self.should_stop.store(true, .seq_cst);
    self.period_ms.store(0, .seq_cst);
    if (self.pid) |thread| thread.detach();
}

fn loop(self: *This) !void {
    var should_stop = self.should_stop.load(.seq_cst);
    while (!should_stop) {
        const sleep_time = self.period_ms.load(.seq_cst) * std.time.ns_per_ms;
        std.time.sleep(sleep_time);
        if (self.callback) |cb| cb(self.name, self.ctx);
        should_stop = self.should_stop.load(.seq_cst);
    }
}
