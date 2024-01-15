const std = @import("std");
const Client = @import("client.zig");

queue: Queue,

const This = @This();
const Queue = std.fifo.LinearFifo(Command, .Dynamic);

pub const Kind = enum {
    enabled,
    level,
    pan,
    level_in,
    level_cut,
    rate,
    loop_start,
    loop_end,
    loop_flag,
    position,
    fade_time,
    rec_level,
    pre_level,
    rec_offset,
    pre_filter_fc,
    pre_filter_fc_mod,
    pre_filter_rq,
    pre_filter_lp,
    pre_filter_hp,
    pre_filter_bp,
    pre_filter_br,
    pre_filter_dry,
    post_filter_fc,
    post_filter_rq,
    post_filter_lp,
    post_filter_hp,
    post_filter_bp,
    post_filter_br,
    post_filter_dry,
    level_slew_time,
    pan_slew_time,
    rate_slew_time,
    rec_pre_slew_time,
    voice_sync,
    buffer,
    rec_once,
    rec_flag,
    play_flag,
};

pub fn create(allocator: std.mem.Allocator) !*This {
    const ret = try allocator.create(This);
    ret.* = .{
        .queue = Queue.init(allocator),
    };
    return ret;
}

pub fn handlePending(self: *This, client: *Client) void {
    while (self.queue.readItem()) |command| {
        client.handleCommand(&command);
    }
}

pub fn deinit(self: *This) void {
    self.queue.deinit();
    self.* = undefined;
}

pub fn post(self: *This, kind: Kind, args: anytype) void {
    const info = @typeInfo(@TypeOf(args));
    comptime {
        std.debug.assert(info == .Struct);
        std.debug.assert(info.Struct.is_tuple);
        std.debug.assert(info.Struct.fields.len < 4);
    }
    comptime var num_ints: u2 = 0;
    comptime var num_floats: u1 = 0;
    var command: Command = undefined;
    command.kind = kind;
    inline for (info.Struct.fields, 0..) |field, i| {
        switch (field.type) {
            i32 => {
                switch (num_ints) {
                    0 => {
                        command.int_1 = args[i];
                        num_ints += 1;
                    },
                    1 => {
                        command.int_2 = args[i];
                        num_ints += 1;
                    },
                    else => @compileError("post called with too many int arguments!"),
                }
            },
            f32 => {
                switch (num_floats) {
                    0 => {
                        command.float = args[i];
                        num_floats += 1;
                    },
                    1 => @compileError("post called with too many float arguments!"),
                }
            },
            else => @compileError("post called with unsupported type " ++ @typeName(field.type) ++ "'"),
        }
    }
    self.queue.writeItem(command) catch @panic("OOM!");
}

pub const Command = struct {
    kind: Kind,
    int_1: i32,
    int_2: i32,
    float: f32,
};
