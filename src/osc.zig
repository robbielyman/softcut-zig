const Client = @import("client.zig");
const Poll = @import("poll.zig");
const nrt = @import("nrt.zig");
const queue = @import("command_queue.zig");
const liblo = @import("liblo");
const std = @import("std");

const logger = std.log.scoped(.osc);

const This = @This();

client: *Client,
quit: bool = false,
thread: liblo.ServerThread,
out_address: liblo.Address,
num_methods: usize = 0,
methods: [256]Method = undefined,
vu_poll: *Poll,
phase_poll: *Poll,
allocator: std.mem.Allocator,

const Method = struct {
    path: [:0]const u8,
    typespec: [:0]const u8,
    context: *This,
};

pub fn init(allocator: std.mem.Allocator, softcut: *Client, port: [:0]const u8) !*This {
    logger.info("server listening on port {s}", .{port});
    const interface = try allocator.create(This);
    interface.* = .{
        .client = softcut,
        .thread = liblo.ServerThread.new(port.ptr, null),
        .out_address = liblo.Address.new("127.0.0.1", "8888"),
        .vu_poll = try Poll.create(allocator, "/poll/softcut/vu"),
        .phase_poll = try Poll.create(allocator, "/poll/softcut/phase"),
        .allocator = allocator,
    };
    interface.vu_poll.callback = vuCallback;
    interface.vu_poll.ctx = interface;
    interface.vu_poll.period_ms.raw = 1;
    interface.phase_poll.callback = phaseCallback;
    interface.phase_poll.ctx = interface;
    interface.phase_poll.period_ms.raw = 1;
    interface.addServerMethods();
    try interface.thread.start();
    return interface;
}

pub fn deinit(this: *This) void {
    this.phase_poll.kill();
    this.vu_poll.kill();
    this.allocator.destroy(this.phase_poll);
    this.allocator.destroy(this.vu_poll);
    this.thread.free();
    this.out_address.free();
}

fn addServerMethod(this: *This, path: [:0]const u8, format: [:0]const u8, comptime handler: liblo.MethodFn) void {
    this.methods[this.num_methods] = .{
        .path = path,
        .typespec = format,
        .context = this,
    };
    _ = this.thread.addMethod(path, null, liblo.wrap(handler), &this.methods[this.num_methods]);
    this.num_methods += 1;
}

pub fn addServerMethods(this: *This) void {

    // basics
    this.addServerMethod("/hello", "", Methods.hello);
    this.addServerMethod("/goodbye", "", Methods.goodbye);
    this.addServerMethod("/quit", "", Methods.quit);

    // polls
    this.addServerMethod("/poll/start/vu", "", Methods.pollVuStart);
    this.addServerMethod("/poll/stop/vu", "", Methods.pollVuStop);

    // routing
    this.addServerMethod("/set/enabled/cut", "if", Methods.setEnabled);
    this.addServerMethod("/set/level/cut", "if", Methods.setLevel);
    this.addServerMethod("/set/pan/cut", "if", Methods.setPan);

    // levels
    this.addServerMethod("/set/level/in_cut", "iif", Methods.setLevelIn);
    this.addServerMethod("/set/level/cut_cut", "iif", Methods.setLevelCut);

    // params
    this.addServerMethod("/set/param/cut/rate", "if", Methods.setRate);
    this.addServerMethod("/set/param/cut/loop_start", "if", Methods.setLoopStart);
    this.addServerMethod("/set/param/cut/loop_end", "if", Methods.setLoopEnd);
    this.addServerMethod("/set/param/cut/loop_flag", "if", Methods.setLoopFlag);
    this.addServerMethod("/set/param/cut/fade_time", "if", Methods.setFadeTime);
    this.addServerMethod("/set/param/cut/rec_level", "if", Methods.setRecLevel);
    this.addServerMethod("/set/param/cut/pre_level", "if", Methods.setPreLevel);
    this.addServerMethod("/set/param/cut/rec_flag", "if", Methods.setRecFlag);
    this.addServerMethod("/set/param/cut/rec_once", "if", Methods.setRecOnce);
    this.addServerMethod("/set/param/cut/play_flag", "if", Methods.setPlayFlag);
    this.addServerMethod("/set/param/cut/rec_offset", "if", Methods.setRecOffset);
    this.addServerMethod("/set/param/cut/position", "if", Methods.setPosition);
    this.addServerMethod("/set/param/cut/pre_filter_fc", "if", Methods.setPreFilterFc);
    this.addServerMethod("/set/param/cut/pre_filter_fc_mod", "if", Methods.setPreFilterFcMod);
    this.addServerMethod("/set/param/cut/pre_filter_rq", "if", Methods.setPreFilterRq);
    this.addServerMethod("/set/param/cut/pre_filter_lp", "if", Methods.setPreFilterLp);
    this.addServerMethod("/set/param/cut/pre_filter_hp", "if", Methods.setPreFilterHp);
    this.addServerMethod("/set/param/cut/pre_filter_bp", "if", Methods.setPreFilterBp);
    this.addServerMethod("/set/param/cut/pre_filter_br", "if", Methods.setPreFilterBr);
    this.addServerMethod("/set/param/cut/pre_filter_dry", "if", Methods.setPreFilterDry);
    this.addServerMethod("/set/param/cut/post_filter_fc", "if", Methods.setPostFilterFc);
    this.addServerMethod("/set/param/cut/post_filter_rq", "if", Methods.setPostFilterRq);
    this.addServerMethod("/set/param/cut/post_filter_lp", "if", Methods.setPostFilterLp);
    this.addServerMethod("/set/param/cut/post_filter_hp", "if", Methods.setPostFilterHp);
    this.addServerMethod("/set/param/cut/post_filter_bp", "if", Methods.setPostFilterBp);
    this.addServerMethod("/set/param/cut/post_filter_br", "if", Methods.setPostFilterBr);
    this.addServerMethod("/set/param/cut/post_filter_dry", "if", Methods.setPostFilterDry);
    this.addServerMethod("/set/param/cut/voice_sync", "iif", Methods.setVoiceSync);
    this.addServerMethod("/set/param/cut/level_slew_time", "if", Methods.setLevelSlewTime);
    this.addServerMethod("/set/param/cut/pan_slew_time", "if", Methods.setPanSlewTime);
    this.addServerMethod("/set/param/cut/recpre_slew_time", "if", Methods.setRecPreSlewTime);
    this.addServerMethod("/set/param/cut/rate_slew_time", "if", Methods.setRateSlewTime);
    this.addServerMethod("/set/param/cut/buffer", "ii", Methods.setBuffer);

    // nrt
    this.addServerMethod("/softcut/buffer/read_mono", "sfffii", Methods.readMono);

    this.addServerMethod("/softcut/buffer/read_stereo", "sfff", Methods.readStereo);

    this.addServerMethod("/softcut/buffer/write_mono", "sffi", Methods.writeMono);

    this.addServerMethod("/softcut/buffer/write_stereo", "sff", Methods.writeStereo);

    // clear
    this.addServerMethod("/softcut/buffer/clear", "", Methods.clearBuffer);
    this.addServerMethod("/softcut/buffer/clear_channel", "i", Methods.clearChannel);
    this.addServerMethod("/softcut/buffer/clear_region", "ff", Methods.clearBufferRegion);
    this.addServerMethod("/softcut/buffer/clear_region_channel", "iff", Methods.clearChannelRegion);
    this.addServerMethod("/softcut/reset", "", Methods.reset);

    // polls
    this.addServerMethod("/set/param/cut/phase_quant", "if", Methods.setPhaseQuant);
    this.addServerMethod("/set/param/cut/phase_offset", "if", Methods.setPhaseOffset);

    this.addServerMethod("/poll/start/cut/phase", "", Methods.phasePollStart);
    this.addServerMethod("/poll/stop/cut/phase", "", Methods.phasePollStop);

    _ = this.thread.addMethod(null, null, liblo.wrap(Methods.catchAll), null);
}

pub fn printServerMethods(this: This) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    for (0..this.num_methods) |i| {
        try stdout.print("{s}\t{s}\n", .{
            this.methods[i].path,
            this.methods[i].typespec,
        });
    }
    try bw.flush();
}

const Methods = struct {
    fn hello(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        _ = ctx; // autofix
        const stdout = std.io.getStdOut().writer();
        stdout.print("hello\n", .{}) catch return true;
        return false;
    }

    fn goodbye(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.quit = true;
        const stdout = std.io.getStdOut().writer();
        stdout.print("goodbye\n", .{}) catch return true;
        return false;
    }

    fn quit(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.quit = true;
        return false;
    }

    fn pollVuStart(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.vu_poll.start();
        return false;
    }

    fn pollVuStop(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.vu_poll.stop();
        return false;
    }

    fn setEnabled(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.enabled, .{ i, f });
        return false;
    }

    fn setLevel(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.level, .{ i, f });
        return false;
    }

    fn setPan(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pan, .{ i, f });
        return false;
    }

    fn setLevelIn(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const j = msg.getArg(i32, 1) catch return true;
        const f: f32 = msg.getArg(f32, 2) catch blk: {
            const fi = msg.getArg(i32, 2) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.level_in, .{ i, j, f });
        return false;
    }

    fn setLevelCut(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const j = msg.getArg(i32, 1) catch return true;
        const f: f32 = msg.getArg(f32, 2) catch blk: {
            const fi = msg.getArg(i32, 2) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.level_cut, .{ i, j, f });
        return false;
    }

    fn setRate(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rate, .{ i, f });
        return false;
    }

    fn setLoopStart(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.loop_start, .{ i, f });
        return false;
    }

    fn setLoopEnd(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.loop_end, .{ i, f });
        return false;
    }

    fn setLoopFlag(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.loop_flag, .{ i, f });
        return false;
    }

    fn setFadeTime(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.fade_time, .{ i, f });
        return false;
    }

    fn setRecLevel(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rec_level, .{ i, f });
        return false;
    }

    fn setPreLevel(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_level, .{ i, f });
        return false;
    }

    fn setRecFlag(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rec_flag, .{ i, f });
        return false;
    }

    fn setRecOnce(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rec_once, .{ i, f });
        return false;
    }

    fn setRecOffset(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rec_offset, .{ i, f });
        return false;
    }

    fn setPosition(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.position, .{ i, f });
        return false;
    }

    fn setPlayFlag(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.play_flag, .{ i, f });
        return false;
    }

    fn setPreFilterFc(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_fc, .{ i, f });
        return false;
    }

    fn setPreFilterFcMod(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_fc_mod, .{ i, f });
        return false;
    }

    fn setPreFilterRq(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_rq, .{ i, f });
        return false;
    }

    fn setPreFilterLp(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_lp, .{ i, f });
        return false;
    }

    fn setPreFilterHp(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_hp, .{ i, f });
        return false;
    }

    fn setPreFilterBp(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_bp, .{ i, f });
        return false;
    }

    fn setPreFilterBr(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_br, .{ i, f });
        return false;
    }

    fn setPreFilterDry(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pre_filter_dry, .{ i, f });
        return false;
    }

    fn setPostFilterFc(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_fc, .{ i, f });
        return false;
    }

    fn setPostFilterRq(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_rq, .{ i, f });
        return false;
    }

    fn setPostFilterLp(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_lp, .{ i, f });
        return false;
    }

    fn setPostFilterHp(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_hp, .{ i, f });
        return false;
    }

    fn setPostFilterBp(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_bp, .{ i, f });
        return false;
    }

    fn setPostFilterBr(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_br, .{ i, f });
        return false;
    }

    fn setPostFilterDry(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.post_filter_dry, .{ i, f });
        return false;
    }

    fn setVoiceSync(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const j = msg.getArg(i32, 1) catch return true;
        const f: f32 = msg.getArg(f32, 2) catch blk: {
            const fi = msg.getArg(i32, 2) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.voice_sync, .{ i, j, f });
        return false;
    }

    fn setLevelSlewTime(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.level_slew_time, .{ i, f });
        return false;
    }

    fn setPanSlewTime(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.pan_slew_time, .{ i, f });
        return false;
    }

    fn setRateSlewTime(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rate_slew_time, .{ i, f });
        return false;
    }

    fn setRecPreSlewTime(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.queue.post(.rec_pre_slew_time, .{ i, f });
        return false;
    }

    fn setBuffer(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const j = msg.getArg(i32, 1) catch return true;
        method.context.client.queue.post(.buffer, .{ i, j });
        return false;
    }

    fn readMono(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const count = msg.argCount();
        if (count < 1) return true;
        var opts: nrt.Options(.ReadMono) = .{
            .idx = method.context.client.bufIdx[0],
            .path = msg.getArg([:0]const u8, 0) catch return true,
        };
        defer {
            method.context.client.nrt.request(.ReadMono, opts) catch {
                logger.err("unable to request job!", .{});
            };
        }
        if (count < 2) return false;
        opts.start_source = msg.getArg(f32, 1) catch return true;
        if (count < 3) return false;
        opts.start_dst = msg.getArg(f32, 2) catch return true;
        if (count < 4) return false;
        opts.duration = msg.getArg(f32, 3) catch return true;
        if (count < 5) return false;
        const chan_source = msg.getArg(i32, 4) catch return true;
        if (chan_source < 0) return true;
        opts.chan_source = @intCast(chan_source);
        if (count < 6) return false;
        const idx = msg.getArg(i32, 5) catch return true;
        if (idx != 0) opts.idx = method.context.client.bufIdx[1];
        return false;
    }

    fn readStereo(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const count = msg.argCount();
        if (count < 1) return true;
        var opts: nrt.Options(.ReadStereo) = .{
            .idx0 = method.context.client.bufIdx[0],
            .idx1 = method.context.client.bufIdx[1],
            .path = msg.getArg([:0]const u8, 0) catch return true,
        };
        defer {
            method.context.client.nrt.request(.ReadStereo, opts) catch {
                logger.err("unable to request job!", .{});
            };
        }
        if (count < 2) return false;
        opts.start_source = msg.getArg(f32, 1) catch return true;
        if (count < 3) return false;
        opts.start_dst = msg.getArg(f32, 2) catch return true;
        if (count < 4) return false;
        opts.duration = msg.getArg(f32, 3) catch return true;
        return false;
    }

    fn writeMono(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const count = msg.argCount();
        if (count < 1) return true;
        var opts: nrt.Options(.WriteMono) = .{
            .idx = method.context.client.bufIdx[0],
            .path = msg.getArg([:0]const u8, 0) catch return true,
        };
        defer {
            method.context.client.nrt.request(.WriteMono, opts) catch {
                logger.err("unable to request job!", .{});
            };
        }
        if (count < 2) return false;
        opts.start = msg.getArg(f32, 1) catch return true;
        if (count < 3) return false;
        opts.duration = msg.getArg(f32, 2) catch return true;
        if (count < 4) return false;
        const idx = msg.getArg(i32, 3) catch return true;
        if (idx != 0) opts.idx = method.context.client.bufIdx[1];
        return false;
    }

    fn writeStereo(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const count = msg.argCount();
        if (count < 1) return true;
        var opts: nrt.Options(.WriteStereo) = .{
            .idx0 = method.context.client.bufIdx[0],
            .idx1 = method.context.client.bufIdx[1],
            .path = msg.getArg([:0]const u8, 0) catch return true,
        };
        defer {
            method.context.client.nrt.request(.WriteStereo, opts) catch {
                logger.err("unable to request job!", .{});
            };
        }
        if (count < 2) return false;
        opts.start = msg.getArg(f32, 1) catch return true;
        if (count < 3) return false;
        opts.duration = msg.getArg(f32, 2) catch return true;
        return false;
    }

    fn clearBuffer(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.client.clearBuffer(0);
        method.context.client.clearBuffer(1);
        return false;
    }

    fn clearChannel(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        method.context.client.clearBuffer(i);
        return false;
    }

    fn clearBufferRegion(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const f1: f32 = msg.getArg(f32, 0) catch blk: {
            const fi = msg.getArg(i32, 0) catch return true;
            break :blk @floatFromInt(fi);
        };
        const f2: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.clearBufferRegion(0, f1, f2);
        method.context.client.clearBufferRegion(1, f1, f2);
        return false;
    }

    fn clearChannelRegion(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f1: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        const f2: f32 = msg.getArg(f32, 2) catch blk: {
            const fi = msg.getArg(i32, 2) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.clearBufferRegion(i, f1, f2);
        return false;
    }

    fn reset(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.client.clearBuffer(0);
        method.context.client.clearBuffer(1);
        method.context.client.reset();
        method.context.phase_poll.stop();
        return false;
    }

    fn setPhaseQuant(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.setPhaseQuant(i, f);
        return false;
    }

    fn setPhaseOffset(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        const i = msg.getArg(i32, 0) catch return true;
        const f: f32 = msg.getArg(f32, 1) catch blk: {
            const fi = msg.getArg(i32, 1) catch return true;
            break :blk @floatFromInt(fi);
        };
        method.context.client.setPhaseOffset(i, f);
        return false;
    }

    fn phasePollStart(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.phase_poll.start();
        return false;
    }

    fn phasePollStop(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = path; // autofix
        _ = msg; // autofix
        const method: *Method = @ptrCast(@alignCast(ctx orelse return true));
        method.context.phase_poll.stop();
        return false;
    }

    fn catchAll(path: [*:0]const u8, msg: liblo.Message, ctx: ?*anyopaque) bool {
        _ = msg; // autofix
        _ = ctx; // autofix
        logger.warn("not responding to message at path {s}; check your arguments?", .{path});
        return false;
    }
};

fn phaseCallback(path: [:0]const u8, ctx: *anyopaque) void {
    var msg = liblo.Message.new();
    defer msg.free();
    msg.add(.{ -1, @as(f32, 0) }) catch return;
    const self: *This = @ptrCast(@alignCast(ctx));
    for (0..Client.num_voices) |i| {
        if (self.client.checkVoiceQuantPhase(i)) {
            const args = msg.argValues().?;
            args[0].?.i = @intCast(i);
            args[1].?.f = @floatCast(self.client.getQuantPhase(i));
            liblo.sendMessage(self.out_address, path, msg) catch return;
        }
    }
}

fn vuCallback(path: [:0]const u8, ctx: *anyopaque) void {
    _ = path; // autofix
    _ = ctx; // autofix
}
