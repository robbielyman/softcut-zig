const std = @import("std");
const sndfile = @import("libsndfile");

const logger = std.log.scoped(.nrt);

const This = @This();

allocator: std.mem.Allocator,
mutex: std.Thread.Mutex,
cond: std.Thread.Condition,
queue: Queue,
pid: std.Thread,
buffers: [16][]f32,
num_bufs: usize,
quit: bool,
sample_rate: usize,

const io_buf_frames = 1024;

pub const Job = struct {
    kind: Kind,
    buffer_idx: [2]usize,
    path: [:0]const u8,
    start_src: f32,
    start_dst: f32,
    duration: f32,
    chan: usize,

    pub const Kind = enum {
        Clear,
        ReadMono,
        ReadStereo,
        WriteMono,
        WriteStereo,
    };
};

const Queue = std.fifo.LinearFifo(Job, .Dynamic);

pub fn init(allocator: std.mem.Allocator, sample_rate: usize) !*This {
    const self = try allocator.create(This);

    self.* = .{
        .allocator = allocator,
        .mutex = .{},
        .cond = .{},
        .queue = Queue.init(allocator),
        .quit = false,
        .buffers = undefined,
        .num_bufs = 0,
        .sample_rate = sample_rate,
        .pid = try std.Thread.spawn(.{}, workLoop, .{self}),
    };

    return self;
}

pub fn registerBuffer(self: *This, buffer: []f32) ?usize {
    if (self.num_bufs >= self.buffers.len) return null;
    self.buffers[self.num_bufs] = buffer;
    defer self.num_bufs += 1;
    return self.num_bufs;
}

pub fn deinit(self: *This) void {
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.quit = true;
    }
    self.cond.signal();
    self.pid.join();
    self.queue.deinit();
}

pub fn Options(comptime kind: Job.Kind) type {
    return switch (kind) {
        .Clear => struct {
            idx: usize,
            start: f32 = 0,
            duration: f32 = -1,
        },
        .ReadMono => struct {
            idx: usize,
            path: [:0]const u8,
            start_source: f32 = 0,
            chan_source: usize = 0,
            start_dst: f32 = 0,
            duration: f32 = -1,
        },
        .ReadStereo => struct {
            idx0: usize,
            idx1: usize,
            path: [:0]const u8,
            start_source: f32 = 0,
            start_dst: f32 = 0,
            duration: f32 = -1,
        },
        .WriteMono => struct {
            idx: usize,
            path: [:0]const u8,
            start: f32 = 0,
            duration: f32 = -1,
        },
        .WriteStereo => struct {
            idx0: usize,
            idx1: usize,
            path: [:0]const u8,
            start: f32 = 0,
            duration: f32 = -1,
        },
    };
}

pub fn request(self: *This, comptime kind: Job.Kind, options: Options(kind)) !void {
    const job: Job = switch (kind) {
        .Clear => .{
            .kind = kind,
            .buffer_idx = .{ options.idx, undefined },
            .path = undefined,
            .start_src = options.start,
            .start_dst = undefined,
            .duration = options.duration,
            .chan = undefined,
        },
        .ReadMono => .{
            .kind = kind,
            .buffer_idx = .{ options.idx, undefined },
            .path = try self.allocator.dupeZ(u8, options.path),
            .start_src = options.start_source,
            .start_dst = options.start_dst,
            .duration = options.duration,
            .chan = options.chan_source,
        },
        .ReadStereo => .{
            .kind = kind,
            .buffer_idx = .{ options.idx0, options.idx1 },
            .path = try self.allocator.dupeZ(u8, options.path),
            .start_src = options.start_source,
            .start_dst = options.start_dst,
            .duration = options.duration,
            .chan = undefined,
        },
        .WriteMono => .{
            .kind = kind,
            .buffer_idx = .{ options.idx, undefined },
            .path = try self.allocator.dupeZ(u8, options.path),
            .start_src = options.start,
            .start_dst = undefined,
            .duration = options.duration,
            .chan = undefined,
        },
        .WriteStereo => .{
            .kind = kind,
            .buffer_idx = .{ options.idx0, options.idx1 },
            .path = try self.allocator.dupeZ(u8, options.path),
            .start_src = options.start,
            .start_dst = undefined,
            .duration = options.duration,
            .chan = undefined,
        },
    };
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.queue.writeItem(job);
    }
    self.cond.signal();
}

fn workLoop(self: *This) void {
    while (!self.quit) {
        var job = job: {
            self.mutex.lock();
            defer self.mutex.unlock();
            break :job self.queue.readItem();
        };
        while (job) |j| {
            switch (j.kind) {
                .Clear => clearBuffer(
                    self.buffers[j.buffer_idx[0]],
                    j.start_src,
                    j.duration,
                    self.sample_rate,
                ),
                .ReadMono => {
                    defer self.allocator.free(j.path);
                    readBufferMono(
                        self.buffers[j.buffer_idx[0]],
                        j.path,
                        j.start_src,
                        j.start_dst,
                        j.duration,
                        j.chan,
                        self.sample_rate,
                    );
                },
                .ReadStereo => {
                    defer self.allocator.free(j.path);
                    readBufferStereo(
                        self.buffers[j.buffer_idx[0]],
                        self.buffers[j.buffer_idx[1]],
                        j.path,
                        j.start_src,
                        j.start_dst,
                        j.duration,
                        self.sample_rate,
                    );
                },
                .WriteMono => {
                    defer self.allocator.free(j.path);
                    writeBufferMono(
                        self.buffers[j.buffer_idx[0]],
                        j.path,
                        j.start_src,
                        j.duration,
                        self.sample_rate,
                    );
                },
                .WriteStereo => {
                    defer self.allocator.free(j.path);
                    writeBufferStereo(
                        self.buffers[j.buffer_idx[0]],
                        self.buffers[j.buffer_idx[1]],
                        j.path,
                        j.start_src,
                        j.duration,
                        self.sample_rate,
                    );
                },
            }
            {
                self.mutex.lock();
                defer self.mutex.unlock();
                job = self.queue.readItem();
            }
        }
        self.mutex.lock();
        defer self.mutex.unlock();
        self.cond.wait(&self.mutex);
    }
    // we're quitting, so just free memory;
    var job = self.queue.readItem();
    while (job) |j| {
        switch (j.kind) {
            .Clear => {},
            else => self.allocator.free(j.path),
        }
        job = self.queue.readItem();
    }
}

fn secToFrame(sec: f32, sample_rate: usize) usize {
    const actual_sec = @max(sec, 0);
    const sr: f32 = @floatFromInt(sample_rate);
    return @intFromFloat(sr * actual_sec);
}

fn clamp(a: *usize, b: usize) void {
    if (a.* > b) a.* = b;
}

fn clearBuffer(buf: []f32, start: f32, dur: f32, sr: usize) void {
    var frA = secToFrame(start, sr);
    clamp(&frA, buf.len - 1);
    var frB = if (dur < 0) buf.len else frA + secToFrame(dur, sr);
    clamp(&frB, buf.len);
    @memset(buf[frA..frB], 0);
}

fn readBufferMono(
    buf: []f32,
    path: [:0]const u8,
    start_src: f32,
    start_dst: f32,
    dur: f32,
    chan: usize,
    sr: usize,
) void {
    var scratch: [8 * io_buf_frames]f32 = undefined;
    var info: sndfile.Info = undefined;
    var file = sndfile.SndFile.open(path, .Read, &info) catch {
        logger.err("readBufferMono(): unable to open file at {s}", .{path});
        return;
    };
    defer {
        file.close() catch {};
    }
    if (info.frames < 1) {
        logger.err("readBufferMono(): empty file!", .{});
        return;
    }
    if (info.samplerate != @as(c_int, @intCast(sr))) {
        logger.err("readBufferMono(): sample rate mismatch: expected: {d}, found: {d}", .{ sr, info.samplerate });
        return;
    }
    if (info.channels < 1 or info.channels > 8) {
        logger.err("readBufferMono(): bad number of channels!", .{});
        return;
    }

    var frSrc = secToFrame(start_src, sr);
    clamp(&frSrc, @intCast(info.frames - 1));

    var frDst = secToFrame(start_dst, sr);
    clamp(&frDst, buf.len - 1);

    const frDur: usize = if (dur < 0)
        @min(@as(usize, @intCast(info.frames)) - frSrc, buf.len - frDst)
    else
        secToFrame(dur, sr);

    const chan_total: usize = @intCast(info.channels);
    const ch: usize = @min(chan_total - 1, chan);

    logger.info("reading sound file channel {d}", .{ch});
    const num_blocks = @divFloor(frDur, io_buf_frames);
    const rem = frDur - (num_blocks * io_buf_frames);
    logger.info("file contains {d} frames", .{info.frames});
    logger.info("reading {d} blocks and {d} remainder frames...", .{ num_blocks, rem });
    for (0..num_blocks) |_| {
        _ = file.seek(@intCast(frSrc), .Set) catch {
            logger.err("error seeking to frame {d}; aborting read", .{frSrc});
            return;
        };
        _ = file.readFloats(scratch[0 .. chan_total * io_buf_frames]) catch {
            logger.err("error reading at frame {d}; aborting", .{frSrc});
            return;
        };
        for (0..io_buf_frames) |frame| {
            buf[frDst] = scratch[frame * chan_total + ch];
            frDst += 1;
        }
        frSrc += io_buf_frames;
    }
    _ = file.seek(@intCast(frSrc), .Set) catch {
        logger.err("error seeking to frame {d}; aborting read", .{frSrc});
        return;
    };
    _ = file.readFloats(scratch[0 .. chan_total * rem]) catch {
        logger.err("error reading at frame {d}; aborting", .{frSrc});
        return;
    };
    for (0..rem) |frame| {
        buf[frDst] = scratch[frame * chan_total + ch];
        frDst += 1;
    }
    logger.info("readBufferMono() done; read {d} frames", .{frDur});
}

fn readBufferStereo(
    left: []f32,
    right: []f32,
    path: [:0]const u8,
    start_src: f32,
    start_dst: f32,
    dur: f32,
    sr: usize,
) void {
    var scratch: [8 * io_buf_frames]f32 = undefined;
    const buf_frames = @min(left.len, right.len);

    var info: sndfile.Info = undefined;
    var file = sndfile.SndFile.open(path, .Read, &info) catch {
        logger.err("readBufferStereo(): unable to open file at {s}", .{path});
        return;
    };
    defer {
        file.close() catch {};
    }
    if (info.frames < 1) {
        logger.err("readBufferStereo(): empty file!", .{});
        return;
    }
    if (info.samplerate != @as(c_int, @intCast(sr))) {
        logger.err("readBufferMono(): sample rate mismatch: expected: {d}, found: {d}", .{ sr, info.samplerate });
        return;
    }
    if (info.channels < 2 or info.channels > 8) {
        logger.err("readBufferStereo(): bad number of channels!", .{});
        return;
    }

    var frSrc = secToFrame(start_src, sr);
    clamp(&frSrc, @intCast(info.frames - 1));

    var frDst = secToFrame(start_dst, sr);
    clamp(&frDst, buf_frames - 1);

    const frDur: usize = if (dur < 0)
        @min(@as(usize, @intCast(info.frames)) - frSrc, buf_frames - frDst)
    else
        secToFrame(dur, sr);

    const chan_total: usize = @intCast(info.channels);

    const num_blocks = @divFloor(frDur, io_buf_frames);
    const rem = frDur - (num_blocks * io_buf_frames);
    logger.info("file contains {d} frames", .{info.frames});
    logger.info("reading {d} blocks and {d} remainder frames...", .{ num_blocks, rem });
    for (0..num_blocks) |_| {
        _ = file.seek(@intCast(frSrc), .Set) catch {
            logger.err("error seeking to frame {d}; aborting read", .{frSrc});
            return;
        };
        _ = file.readFloats(scratch[0 .. chan_total * io_buf_frames]) catch {
            logger.err("error reading at frame {d}; aborting", .{frSrc});
            return;
        };
        for (0..io_buf_frames) |frame| {
            left[frDst] = scratch[frame * chan_total];
            right[frDst] = scratch[frame * chan_total + 1];
            frDst += 1;
        }
        frSrc += io_buf_frames;
    }
    _ = file.seek(@intCast(frSrc), .Set) catch {
        logger.err("error seeking to frame {d}; aborting read", .{frSrc});
        return;
    };
    _ = file.readFloats(scratch[0 .. chan_total * rem]) catch {
        logger.err("error reading at frame {d}; aborting", .{frSrc});
        return;
    };
    for (0..rem) |frame| {
        left[frDst] = scratch[frame * chan_total];
        right[frDst] = scratch[frame * chan_total + 1];
        frDst += 1;
    }
    logger.info("readBufferStereo() done; read {d} frames", .{frDur});
}

fn writeBufferMono(
    buf: []const f32,
    path: [:0]const u8,
    start_src: f32,
    dur: f32,
    sr: usize,
) void {
    var info: sndfile.Info = .{
        .samplerate = @intCast(sr),
        .channels = 1,
        .format = sndfile.c.SF_FORMAT_WAV | sndfile.c.SF_FORMAT_PCM_24,
    };
    var file = sndfile.SndFile.open(path, .Write, &info) catch {
        logger.err("writeBufferMono(): cannot open file at {s} for writing", .{path});
        return;
    };
    defer {
        file.writeSync();
        file.close() catch {};
    }

    _ = sndfile.c.sf_command(file.handle, sndfile.c.SFC_SET_CLIPPING, null, sndfile.c.SF_TRUE);

    var frSrc = secToFrame(start_src, sr);
    clamp(&frSrc, buf.len);

    const frDur = if (dur < 0) buf.len - frSrc else secToFrame(dur, sr);

    const num_blocks = @divFloor(frDur, io_buf_frames);
    const rem = frDur - (num_blocks * io_buf_frames);

    for (0..num_blocks) |i| {
        file.writeFloats(buf[i * io_buf_frames ..][0..io_buf_frames]) catch {
            logger.err("writeBufferMono(): write aborted after {d} frames", .{i * io_buf_frames});
            return;
        };
    }
    file.writeFloats(buf[num_blocks * io_buf_frames ..][0..rem]) catch {
        logger.err("writeBufferMono(): write aborted after {d} frames", .{num_blocks * io_buf_frames});
    };
}

fn writeBufferStereo(
    left: []const f32,
    right: []const f32,
    path: [:0]const u8,
    start_src: f32,
    dur: f32,
    sr: usize,
) void {
    var info: sndfile.Info = .{
        .samplerate = @intCast(sr),
        .channels = 2,
        .format = sndfile.c.SF_FORMAT_WAV | sndfile.c.SF_FORMAT_PCM_24,
    };
    var file = sndfile.SndFile.open(path, .Write, &info) catch {
        logger.err("writeBufferStereo(): cannot open file at {s} for writing", .{path});
        return;
    };
    defer {
        file.writeSync();
        file.close() catch {};
    }

    _ = sndfile.c.sf_command(file.handle, sndfile.c.SFC_SET_CLIPPING, null, sndfile.c.SF_TRUE);

    var frSrc = secToFrame(start_src, sr);
    const buf_frames = @min(left.len, right.len);
    clamp(&frSrc, buf_frames);

    const frDur = if (dur < 0) buf_frames - frSrc else secToFrame(dur, sr);

    const num_blocks = @divFloor(frDur, io_buf_frames);
    const rem = frDur - (num_blocks * io_buf_frames);

    var scratch: [2 * io_buf_frames]f32 = undefined;

    for (0..num_blocks) |i| {
        for (0..io_buf_frames) |j| {
            scratch[2 * j] = left[frSrc + j];
            scratch[2 * j + 1] = right[frSrc + j];
        }
        file.writeFloats(&scratch) catch {
            logger.err("writeBufferStereo(): write aborted after {d} frames", .{i * io_buf_frames});
            return;
        };
        frSrc += io_buf_frames;
    }
    for (0..rem) |j| {
        scratch[2 * j] = left[frSrc + j];
        scratch[2 * j + 1] = right[frSrc + j];
    }
    file.writeFloats(scratch[0 .. 2 * rem]) catch {
        logger.err("writeBufferStereo(): write aborted after {d} frames", .{num_blocks * io_buf_frames});
    };
}
