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

    if (!in_dev.supportsSampleRate(48000) or !out_dev.supportsSampleRate(48000)) return error.BadSampleRate;

    const instream = try in_dev.createInStream();
    instream.handle.sample_rate = @intCast(48000);
    const outstream = try out_dev.createOutStream();
    outstream.handle.sample_rate = @intCast(48000);

    this.* = .{
        .ctx = ctx,
        .in_dev = in_dev,
        .out_dev = out_dev,
        .instream = instream,
        .outstream = outstream,
        .context = .{
            .client = client,
            .left = try libsoundio.RingBuffer.create(ctx, 4096 * 32 * 32 * 32),
            .right = try libsoundio.RingBuffer.create(ctx, 4096 * 32 * 32 * 32),
        },
    };
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

    self.outstream.handle.format = @intCast(@intFromEnum(libsoundio.Float32NE));
    self.instream.handle.format = @intCast(@intFromEnum(libsoundio.Float32NE));

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

    var left_write_ptr = context.left.writePtr();
    var right_write_ptr = context.right.writePtr();

    const bytes_per_frame: usize = @intCast(in.handle.bytes_per_frame);
    const bytes_per_sample: usize = @intCast(in.handle.bytes_per_sample);
    const left_free_bytes = context.left.freeCount();
    const right_free_bytes = context.right.freeCount();

    const left_free = @divExact(left_free_bytes, bytes_per_frame);
    const right_free = @divExact(right_free_bytes, bytes_per_frame);

    if (left_free < min or right_free < min) return;
    const read_frames = @min(@min(left_free, right_free), max);

    var frames_to_read = read_frames;

    while (true) {
        var areas: ?[*]libsoundio.c.SoundIoChannelArea = undefined;
        const frame_count = in.beginRead(&areas, frames_to_read) catch return;
        if (frame_count == 0) break;
        if (areas) |a| {
            var left_src: [*]u8 = a[0].ptr.?;
            const left_step: usize = @intCast(a[0].step);
            const right_step: usize = @intCast(a[1].step);
            var right_src: [*]u8 = a[1].ptr.?;
            for (0..frame_count) |_| {
                @memcpy(left_write_ptr[0..bytes_per_sample], left_src);
                left_src += left_step;

                @memcpy(right_write_ptr[0..bytes_per_sample], right_src);
                right_src += right_step;
            }
        } else {
            const len: usize = frame_count * bytes_per_frame;
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

    const advance_bytes = read_frames * bytes_per_frame;
    context.left.advanceWritePtr(advance_bytes);
    context.right.advanceWritePtr(advance_bytes);
}

fn write(outstream: ?*libsoundio.c.SoundIoOutStream, min_frames: c_int, max_frames: c_int) callconv(.C) void {
    const min: usize = @intCast(@max(min_frames, 0));
    const max: usize = @intCast(@max(max_frames, 0));
    const out: libsoundio.OutStream = .{ .handle = outstream.? };
    const context: *Context = @ptrCast(@alignCast(out.handle.userdata.?));

    var left_read_ptr = context.left.readPtr();
    var right_read_ptr = context.right.readPtr();

    const bytes_per_frame: usize = @intCast(out.handle.bytes_per_frame);
    const bytes_per_sample: usize = @intCast(out.handle.bytes_per_sample);
    const left_filled_bytes = context.left.fillCount();
    const right_filled_bytes = context.right.fillCount();

    const left_filled = @divExact(left_filled_bytes, bytes_per_frame);
    const right_filled = @divExact(right_filled_bytes, bytes_per_frame);

    if (left_filled < min or right_filled < min) {
        // we'll process silence
        var silence: [2048]f32 = .{0} ** 2048;
        var frames_to_write = max;
        while (true) {
            var areas: ?[*]libsoundio.c.SoundIoChannelArea = undefined;
            const frame_count = out.beginWrite(&areas, @min(frames_to_write, 2048)) catch return;
            if (frame_count == 0) break;
            context.client.process(silence[0..frame_count], silence[0..frame_count]);
            const a = areas.?;
            var left_dst: [*]u8 = a[0].ptr.?;
            const left_step: usize = @intCast(a[0].step);
            var right_dst: [*]u8 = a[1].ptr.?;
            const right_step: usize = @intCast(a[1].step);
            for (0..frame_count) |i| {
                const left_ptr: [*]u8 = @ptrCast(context.client.mix.buf[0][i..].ptr);
                const right_ptr: [*]u8 = @ptrCast(context.client.mix.buf[1][i..].ptr);
                @memcpy(left_dst[0..bytes_per_sample], left_ptr);
                left_dst += left_step;
                @memcpy(right_dst[0..bytes_per_sample], right_ptr);
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
        const advance_bytes = frames_to_write * bytes_per_frame;
        context.left.advanceReadPtr(advance_bytes);
        context.right.advanceReadPtr(advance_bytes);
        return;
    }

    const write_frames: usize = @min(@min(left_filled, right_filled), max);

    var frames_to_write = write_frames;
    while (true) {
        var areas: ?[*]libsoundio.c.SoundIoChannelArea = undefined;
        const frame_count = out.beginWrite(&areas, frames_to_write) catch return;
        if (frame_count == 0) break;

        const float_left_read_ptr: [*]const f32 = @ptrCast(@alignCast(left_read_ptr));
        const float_right_read_ptr: [*]const f32 = @ptrCast(@alignCast(right_read_ptr));
        context.client.process(float_left_read_ptr[0..frame_count], float_right_read_ptr[0..frame_count]);
        left_read_ptr += frame_count;
        right_read_ptr += frame_count;

        const a = areas.?;
        var left_dst: [*]u8 = a[0].ptr.?;
        const left_step: usize = @intCast(a[0].step);
        var right_dst: [*]u8 = a[1].ptr.?;
        const right_step: usize = @intCast(a[1].step);

        for (0..frame_count) |i| {
            const left_ptr: [*]u8 = @ptrCast(context.client.mix.buf[0][i..].ptr);
            const right_ptr: [*]u8 = @ptrCast(context.client.mix.buf[1][i..].ptr);
            @memcpy(left_dst[0..bytes_per_sample], left_ptr);
            left_dst += left_step;
            @memcpy(right_dst[0..bytes_per_sample], right_ptr);
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

    const advance_bytes = write_frames * bytes_per_frame;
    context.left.advanceReadPtr(advance_bytes);
    context.right.advanceReadPtr(advance_bytes);
}
