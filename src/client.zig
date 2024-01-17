const std = @import("std");
pub const num_voices = @import("options").voices;
const sc = @import("softcut").Softcut(num_voices);
const CommandQueue = @import("command_queue.zig");
const LogRamp = @import("utilities.zig").LogRamp;
const Bus = @import("bus.zig");

const max_block_frames: usize = 2048;

const StereoBus = Bus.Bus(2, 2048);
const MonoBus = Bus.Bus(1, 2048);
const buf_frames: usize = 2 << 23;

const This = @This();
const NRT = @import("nrt.zig");
const logger = std.log.scoped(.client);

cut: sc,
queue: *CommandQueue,
nrt: *NRT,
// main buffer
buf: [2][buf_frames]f32,

// buffer index
bufIdx: [2]usize,
// busses
mix: StereoBus = .{},
input: [num_voices]MonoBus = .{.{}} ** num_voices,
output: [num_voices]MonoBus = .{.{}} ** num_voices,
// levels
in_level: [2][num_voices]LogRamp,
out_level: [num_voices]LogRamp,
out_pan: [num_voices]LogRamp,
fb_level: [num_voices][num_voices]LogRamp,
vu: [2]f32 = .{ 0, 0 },
// flags
enabled: [num_voices]bool,
quant_phase: [num_voices]f64,
sample_rate: f32,
allocator: std.mem.Allocator,

// caller owns allocated memory.
pub fn create(allocator: std.mem.Allocator) !*This {
    const this = try allocator.create(This);
    this.* = .{
        .cut = try sc.init(),
        .queue = try CommandQueue.create(allocator),
        .nrt = try NRT.init(allocator, 48000),
        .buf = undefined,
        .bufIdx = undefined,
        .in_level = .{
            .{.{}} ** num_voices,
            .{.{}} ** num_voices,
        },
        .out_level = .{.{}} ** num_voices,
        .out_pan = .{.{}} ** num_voices,
        .fb_level = .{.{.{}} ** num_voices} ** num_voices,
        .enabled = .{false} ** num_voices,
        .quant_phase = .{1} ** num_voices,
        .sample_rate = 48000,
        .allocator = allocator,
    };
    this.bufIdx[0] = this.nrt.registerBuffer(&this.buf[0]).?;
    this.bufIdx[1] = this.nrt.registerBuffer(&this.buf[1]).?;
    @memset(&this.buf[0], 0);
    @memset(&this.buf[1], 0);
    this.setSampleRate(48000);
    this.reset();
    return this;
}

pub fn destroy(self: *This) void {
    self.queue.deinit();
    self.allocator.destroy(self.queue);
    self.nrt.deinit();
    self.allocator.destroy(self.nrt);
    self.cut.destroy();
}

fn mixInput(self: *This, left: []const f32, right: []const f32) void {
    for (0..num_voices) |v| {
        if (!(self.cut.getRecFlag(v) catch unreachable)) continue;
        self.input[v].mixFromSlice(left, &self.in_level[0][v]);
        self.input[v].mixFromSlice(right, &self.in_level[1][v]);
        for (0..num_voices) |w| {
            if (!(self.cut.getPlayFlag(w) catch unreachable)) continue;
            self.input[v].mixFrom(&self.input[w], left.len, &self.fb_level[w][v]);
        }
    }
}

fn mixOutput(self: *This, num_frames: usize) void {
    for (0..num_voices) |v| {
        if (!(self.cut.getPlayFlag(v) catch unreachable)) continue;
        self.mix.panMixFrom(&self.output[v], num_frames, &self.out_level[v], &self.out_pan[v]);
    }
    if (num_frames == 0) return;
    var vu: [2]f32 = .{ 0, 0 };
    for (0..num_frames) |i| {
        vu[0] += self.mix.buf[0][i] * self.mix.buf[0][i];
        vu[1] += self.mix.buf[1][i] * self.mix.buf[1][i];
    }
    self.vu = .{ @sqrt(vu[0] / @as(f32, @floatFromInt(num_frames))), @sqrt(vu[1] / @as(f32, @floatFromInt(num_frames))) };
}

fn clearBusses(self: *This, num_frames: usize) void {
    self.mix.clearFrames(num_frames);
    for (&self.input) |*bus| {
        bus.clear();
    }
}

pub fn process(self: *This, left: []const f32, right: []const f32) void {
    std.debug.assert(left.len == right.len);
    const num_frames = left.len;
    self.queue.handlePending(self);
    self.clearBusses(num_frames);
    self.mixInput(left, right);

    inline for (0..num_voices) |v| {
        if (self.enabled[v]) {
            self.cut.processBlock(v, self.input[v].buf[0][0..num_frames], self.output[v].buf[0][0..num_frames]) catch unreachable;
        }
    }

    self.mixOutput(num_frames);
}

pub fn setSampleRate(self: *This, rate: u32) void {
    self.sample_rate = @floatFromInt(rate);
    inline for (0..num_voices) |i| {
        inline for (0..num_voices) |j| {
            self.fb_level[i][j].sample_rate = self.sample_rate;
            self.fb_level[i][j].recalculateB();
        }
    }
    inline for (0..2) |i| {
        inline for (0..num_voices) |j| {
            self.in_level[i][j].sample_rate = self.sample_rate;
            self.in_level[i][j].recalculateB();
        }
    }
    inline for (0..num_voices) |i| {
        self.out_level[i].sample_rate = self.sample_rate;
        self.out_level[i].recalculateB();
        self.out_pan[i].sample_rate = self.sample_rate;
        self.out_pan[i].recalculateB();
    }
    self.cut.setSampleRate(rate);
}

pub fn reset(self: *This) void {
    inline for (0..num_voices) |i| {
        self.cut.setVoiceBuffer(i, &self.buf[i % 2]) catch unreachable;
        self.out_level[i].x0 = 0;
        self.out_level[i].time = 0.001;
        self.out_level[i].recalculateB();
        self.out_pan[i].x0 = 0.5;
        self.out_pan[i].time = 0.001;
        self.out_pan[i].recalculateB();

        self.enabled[i] = false;

        self.setPhaseQuant(@intCast(i), 1.0);
        self.setPhaseOffset(@intCast(i), 0.0);

        for (0..2) |j| {
            self.in_level[j][i].x0 = 0;
            self.in_level[j][i].time = 0.001;
            self.in_level[j][i].recalculateB();
        }

        for (0..num_voices) |j| {
            self.fb_level[j][i].x0 = 0;
            self.fb_level[j][i].time = 0.001;
            self.fb_level[j][i].recalculateB();
        }

        self.cut.setLoopStart(i, @floatFromInt(2 * i)) catch unreachable;
        self.cut.setLoopEnd(i, @floatFromInt(2 * i + 1)) catch unreachable;

        self.output[i].clear();
        self.input[i].clear();
    }

    self.cut.reset();
}

pub fn handleCommand(self: *This, command: *const CommandQueue.Command) void {
    switch (command.kind) {
        .enabled => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.enabled[@intCast(command.int_1)] = command.float > 0;
        },
        .level => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.out_level[@intCast(command.int_1)].x0 = command.float;
        },
        .pan => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.out_pan[@intCast(command.int_1)].x0 = command.float;
        },
        .level_in => {
            if (command.int_1 < 0 or command.int_1 > 1) return;
            if (command.int_2 < 0 or command.int_2 >= num_voices) return;
            self.in_level[@intCast(command.int_1)][@intCast(command.int_2)].x0 = command.float;
        },
        .level_cut => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            if (command.int_2 < 0 or command.int_2 >= num_voices) return;
            self.fb_level[@intCast(command.int_1)][@intCast(command.int_2)].x0 = command.float;
        },
        .rate => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRate(@intCast(command.int_1), command.float) catch unreachable;
        },
        .loop_start => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setLoopStart(@intCast(command.int_1), command.float) catch unreachable;
        },
        .loop_end => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setLoopEnd(@intCast(command.int_1), command.float) catch unreachable;
        },
        .loop_flag => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setLoopFlag(@intCast(command.int_1), command.float > 0) catch unreachable;
        },
        .fade_time => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setFadeTime(@intCast(command.int_1), command.float) catch unreachable;
        },
        .rec_level => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRecLevel(@intCast(command.int_1), command.float) catch unreachable;
        },
        .rec_once => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRecOnceFlag(@intCast(command.int_1), command.float > 0) catch unreachable;
        },
        .pre_level => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreLevel(@intCast(command.int_1), command.float) catch unreachable;
        },
        .rec_flag => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRecFlag(@intCast(command.int_1), command.float > 0) catch unreachable;
        },
        .play_flag => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPlayFlag(@intCast(command.int_1), command.float > 0) catch unreachable;
        },
        .rec_offset => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRecOffset(@intCast(command.int_1), command.float) catch unreachable;
        },
        .position => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.cutToPos(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_fc => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterFc(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_fc_mod => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterFcMod(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_rq => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterRq(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_lp => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterLp(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_hp => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterHp(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_bp => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterBp(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_br => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterBr(@intCast(command.int_1), command.float) catch unreachable;
        },
        .pre_filter_dry => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPreFilterDry(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_fc => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterFc(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_rq => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterRq(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_lp => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterLp(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_hp => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterHp(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_bp => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterBp(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_br => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterBr(@intCast(command.int_1), command.float) catch unreachable;
        },
        .post_filter_dry => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setPostFilterDry(@intCast(command.int_1), command.float) catch unreachable;
        },
        .voice_sync => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            if (command.int_2 < 0 or command.int_2 >= num_voices) return;
            self.cut.syncVoice(@intCast(command.int_1), @intCast(command.int_2), command.float) catch unreachable;
        },
        .level_slew_time => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.out_level[@intCast(command.int_1)].time = command.float;
            self.out_level[@intCast(command.int_1)].recalculateB();
        },
        .pan_slew_time => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.out_pan[@intCast(command.int_1)].time = command.float;
            self.out_pan[@intCast(command.int_1)].recalculateB();
        },
        .rec_pre_slew_time => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRecPreSlewTime(@intCast(command.int_1), command.float) catch unreachable;
        },
        .rate_slew_time => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            self.cut.setRateSlewTime(@intCast(command.int_1), command.float) catch unreachable;
        },
        .buffer => {
            if (command.int_1 < 0 or command.int_1 >= num_voices) return;
            if (command.int_2 < 0 or command.int_2 > 1) return;
            self.cut.setVoiceBuffer(@intCast(command.int_1), &self.buf[@intCast(command.int_2)]) catch unreachable;
        },
    }
}

pub fn clearBuffer(self: *This, buffer: i32) void {
    if (buffer != 0 or buffer != 1) return;
    self.clearBufferRegion(buffer, 0, -1);
}

pub fn clearBufferRegion(self: *This, buffer: i32, start_time: f32, dur: f32) void {
    if (buffer != 0 or buffer != 1) return;
    self.nrt.request(.Clear, .{
        .idx = self.bufIdx[@intCast(buffer)],
        .start = start_time,
        .duration = dur,
    }) catch {
        logger.err("unable to request clear!", .{});
    };
}

pub fn checkVoiceQuantPhase(self: *This, i: usize) bool {
    if (self.quant_phase[i] != self.cut.getQuantPhase(i) catch unreachable) {
        self.quant_phase[i] = self.cut.getQuantPhase(i) catch unreachable;
        return true;
    } else return false;
}

pub fn getQuantPhase(self: *This, i: usize) f64 {
    return self.cut.getQuantPhase(i) catch unreachable;
}

pub fn setPhaseQuant(self: *This, i: i32, f: f32) void {
    if (i < 0 or i > num_voices) return;
    self.cut.setPhaseQuant(@intCast(i), f) catch unreachable;
}

pub fn setPhaseOffset(self: *This, i: i32, f: f32) void {
    if (i < 0 or i > num_voices) return;
    self.cut.setPhaseOffset(@intCast(i), f) catch unreachable;
}
