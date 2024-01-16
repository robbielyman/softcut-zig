const libsoundio = @import("libsoundio");
const Client = @import("client.zig");
const std = @import("std");

const This = @This();

ctx: libsoundio.SoundIo,
in_dev: libsoundio.Device,
out_dev: libsoundio.Device,
instream: libsoundio.InStream,
in_thread: ?std.Thread = null,
outstream: libsoundio.OutStream,
out_thread: ?std.Thread = null,
context: Context,

const softcut_samplerate = 48000;
const softcut_latency = 0.008;
const softcut_format: c_uint = @intCast(@intFromEnum(libsoundio.Float32NE));

const Context = struct {
    client: *Client,
    left: libsoundio.RingBuffer,
    right: libsoundio.RingBuffer,
};

pub fn setup(allocator: std.mem.Allocator, client: *Client, in_index: ?usize, out_index: ?usize) !*This {
    const this = try allocator.create(This);
    const ctx = try libsoundio.SoundIo.create();
    try ctx.connect();
    ctx.flushEvents();

    if (in_index == null) try printSuitableInputDevices(ctx);
    if (out_index == null) try printSuitableOutputDevices(ctx);
    if (in_index == null or out_index == null) return error.NoDevicesGiven;

    const in_dev = try ctx.getInputDevice(in_index.?);
    const out_dev = try ctx.getOutputDevice(out_index.?);

    if (!in_dev.supportsSampleRate(softcut_samplerate) or !out_dev.supportsSampleRate(softcut_samplerate)) return error.BadSampleRate;

    const instream = try in_dev.createInStream();
    instream.handle.sample_rate = @intCast(softcut_samplerate);
    const outstream = try out_dev.createOutStream();
    outstream.handle.sample_rate = @intCast(softcut_samplerate);
    const float_cap: f32 = softcut_latency * softcut_samplerate * 64;
    const cap: usize = @intFromFloat(float_cap);
    const fill_count: usize = @intFromFloat(softcut_latency * softcut_samplerate * 32);

    this.* = .{
        .ctx = ctx,
        .in_dev = in_dev,
        .out_dev = out_dev,
        .instream = instream,
        .outstream = outstream,
        .context = .{
            .client = client,
            .left = try libsoundio.RingBuffer.create(ctx, cap),
            .right = try libsoundio.RingBuffer.create(ctx, cap),
        },
    };

    this.instream.handle.software_latency = softcut_latency;
    this.outstream.handle.software_latency = softcut_latency;

    const left_write_ptr = this.context.left.writePtr();
    @memset(left_write_ptr[0..fill_count], 0);
    this.context.left.advanceWritePtr(fill_count);
    const right_write_ptr = this.context.right.writePtr();
    @memset(right_write_ptr[0..fill_count], 0);
    this.context.right.advanceWritePtr(fill_count);

    return this;
}

pub fn teardown(self: *This) void {
    self.instream.destroy();
    self.outstream.destroy();
    if (self.in_thread) |pid| pid.join();
    if (self.out_thread) |pid| pid.join();
    self.in_dev.unref();
    self.out_dev.unref();
    self.ctx.destroy();
    self.* = undefined;
}

pub fn start(self: *This) !void {
    self.instream.handle.userdata = &self.context;
    self.outstream.handle.userdata = &self.context;

    self.outstream.handle.format = softcut_format;
    self.instream.handle.format = softcut_format;

    const stereo = try libsoundio.Layout.getBuiltin(.IdStereo);
    self.instream.handle.layout = stereo.handle.*;
    self.outstream.handle.layout = stereo.handle.*;

    self.instream.handle.read_callback = read;
    self.outstream.handle.write_callback = write;

    try self.instream.open();
    try self.outstream.open();

    self.out_thread = try std.Thread.spawn(.{}, libsoundio.OutStream.start, .{self.outstream});
    self.in_thread = try std.Thread.spawn(.{}, libsoundio.InStream.start, .{self.instream});
}

fn printSuitableOutputDevices(ctx: libsoundio.SoundIo) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stereo = try libsoundio.Layout.getBuiltin(.IdStereo);
    try stdout.print("listing suitable output devices...\n", .{});
    var found = false;
    const num = try ctx.outputDeviceCount();
    for (0..num) |idx| {
        const dev = try ctx.getOutputDevice(idx);
        defer dev.unref();
        if (!dev.supportsFormat(libsoundio.Float32NE)) continue;
        if (!dev.supportsLayout(stereo)) continue;
        if (!dev.supportsSampleRate(softcut_samplerate)) continue;
        found = true;
        try stdout.print("({d}): {s}\n", .{
            idx, try dev.name(),
        });
    }
    if (found == false) {
        try stdout.print("none found!\n", .{});
        try bw.flush();
        return;
    }
    try stdout.print("select an output device at startup with -o [device_number]\n", .{});
    try bw.flush();
}

fn printSuitableInputDevices(ctx: libsoundio.SoundIo) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stereo = try libsoundio.Layout.getBuiltin(.IdStereo);

    try stdout.print("listing suitable input devices...\n", .{});
    var found = false;
    const num = try ctx.inputDeviceCount();
    for (0..num) |idx| {
        const dev = try ctx.getInputDevice(idx);
        defer dev.unref();
        if (!dev.supportsFormat(libsoundio.Float32NE)) continue;
        if (!dev.supportsLayout(stereo)) continue;
        if (!dev.supportsSampleRate(48000)) continue;
        found = true;
        try stdout.print("({d}): {s}\n", .{
            idx, try dev.name(),
        });
    }
    if (found == false) {
        try stdout.print("none found!\n", .{});
        try bw.flush();
        return;
    }
    try stdout.print("select an input device at startup with -i [device_number]\n", .{});
    try bw.flush();
}

fn read(instream: ?*libsoundio.c.SoundIoInStream, min_frames: c_int, max_frames: c_int) callconv(.C) void {
    const min: usize = @intCast(@max(min_frames, 0));
    const max: usize = @intCast(@max(max_frames, 0));
    const in: libsoundio.InStream = .{ .handle = instream.? };
    const context: *Context = @ptrCast(@alignCast(in.handle.userdata.?));

    var left_write_ptr: [*]f32 = @ptrCast(@alignCast(context.left.writePtr()));
    var right_write_ptr: [*]f32 = @ptrCast(@alignCast(context.right.writePtr()));

    const bytes_per_sample: usize = @intCast(in.handle.bytes_per_sample);
    std.debug.assert(bytes_per_sample == @sizeOf(f32));
    const left_free_bytes = context.left.freeCount();
    const right_free_bytes = context.right.freeCount();

    const left_free = @divExact(left_free_bytes, bytes_per_sample);
    const right_free = @divExact(right_free_bytes, bytes_per_sample);

    if (left_free < min or right_free < min) @panic("ring buffer overflow!");
    const read_frames = @min(@min(left_free, right_free), max);

    var frames_to_read = read_frames;

    while (true) {
        var areas: ?[*]libsoundio.c.SoundIoChannelArea = undefined;
        const frame_count = in.beginRead(&areas, frames_to_read) catch return;
        if (frame_count == 0) break;
        if (areas) |a| {
            var left_src: [*]f32 = @ptrCast(@alignCast(a[0].ptr.?));
            const left_step: usize = @intCast(@divExact(a[0].step, @sizeOf(f32)));
            const right_step: usize = @intCast(@divExact(a[1].step, @sizeOf(f32)));
            var right_src: [*]f32 = @ptrCast(@alignCast(a[1].ptr.?));
            for (0..frame_count) |i| {
                left_write_ptr[i] = left_src[0];
                right_write_ptr[i] = right_src[0];
                left_src += left_step;
                right_src += right_step;
            }
        } else {
            const len: usize = frame_count * bytes_per_sample;
            @memset(left_write_ptr[0..len], 0);
            left_write_ptr += len;
            @memset(right_write_ptr[0..len], 0);
            right_write_ptr += len;
        }
        in.endRead() catch |err| {
            std.debug.print("end read error: {s}\n", .{
                @errorName(err),
            });
            std.process.exit(1);
        };
        frames_to_read -|= frame_count;
        if (frames_to_read == 0) break;
    }

    const advance_bytes = read_frames * bytes_per_sample;
    context.left.advanceWritePtr(advance_bytes);
    context.right.advanceWritePtr(advance_bytes);
}

fn write(outstream: ?*libsoundio.c.SoundIoOutStream, min_frames: c_int, max_frames: c_int) callconv(.C) void {
    const min: usize = @intCast(@max(min_frames, 0));
    const max: usize = @intCast(@max(max_frames, 0));
    const out: libsoundio.OutStream = .{ .handle = outstream.? };
    const context: *Context = @ptrCast(@alignCast(out.handle.userdata.?));

    var left_read_ptr: [*]const f32 = @ptrCast(@alignCast(context.left.readPtr()));
    var right_read_ptr: [*]const f32 = @ptrCast(@alignCast(context.right.readPtr()));

    const bytes_per_sample: usize = @intCast(out.handle.bytes_per_sample);
    const left_filled_bytes = context.left.fillCount();
    const right_filled_bytes = context.right.fillCount();

    const left_filled = @divExact(left_filled_bytes, bytes_per_sample);
    const right_filled = @divExact(right_filled_bytes, bytes_per_sample);

    if (left_filled < min or right_filled < min) @panic("ring buffer underflow!");
    const write_frames: usize = @min(@min(left_filled, right_filled), max);

    var frames_to_write = write_frames;
    while (true) {
        var areas: ?[*]libsoundio.c.SoundIoChannelArea = undefined;
        const frame_count = out.beginWrite(&areas, @min(frames_to_write, 2048)) catch return;
        if (frame_count == 0) break;

        context.client.process(left_read_ptr[0..frame_count], right_read_ptr[0..frame_count]);
        left_read_ptr += frame_count;
        right_read_ptr += frame_count;

        const a = areas.?;
        var left_dst: [*]f32 = @ptrCast(@alignCast(a[0].ptr.?));
        const left_step: usize = @intCast(@divExact(a[0].step, @sizeOf(f32)));
        var right_dst: [*]f32 = @ptrCast(@alignCast(a[1].ptr.?));
        const right_step: usize = @intCast(@divExact(a[1].step, @sizeOf(f32)));

        for (0..frame_count) |i| {
            left_dst[0] = context.client.mix.buf[0][i];
            right_dst[0] = context.client.mix.buf[1][i];
            left_dst += left_step;
            right_dst += right_step;
        }
        out.endWrite() catch |err| {
            std.debug.print("end write error: {s}\n", .{
                @errorName(err),
            });
            std.process.exit(1);
        };
        frames_to_write -|= frame_count;
        if (frames_to_write == 0) break;
    }

    const advance_bytes = write_frames * bytes_per_sample;
    context.left.advanceReadPtr(advance_bytes);
    context.right.advanceReadPtr(advance_bytes);
}
