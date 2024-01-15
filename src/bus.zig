const std = @import("std");
const LogRamp = @import("utilities.zig").LogRamp;

pub fn Bus(comptime N: usize, comptime size: usize) type {
    return struct {
        buf: [N][size]f32 = undefined,

        const This = @This();

        pub fn clear(self: *This) void {
            inline for (0..N) |ch| {
                @memset(&self.buf[ch], 0);
            }
        }

        pub fn clearFrames(self: *This, num_frames: usize) void {
            std.debug.assert(num_frames <= size);
            inline for (0..N) |ch| {
                @memset(self.buf[ch][0..num_frames], 0);
            }
        }

        // assumes that self.buf != other.buf.
        pub fn copyFrom(self: *This, other: *const This, num_frames: usize) void {
            std.debug.assert(num_frames <= size);
            inline for (0..N) |ch| {
                @memcpy(self.buf[ch][0..num_frames], other.buf[ch][0..num_frames]);
            }
        }

        pub fn copyTo(self: *const This, dst: [N][*]f32, num_frames: usize) void {
            std.debug.assert(num_frames <= size);
            inline for (0..N) |ch| {
                @memcpy(dst[ch], self[ch][0..num_frames]);
            }
        }

        pub fn mixFrom(self: *This, other: *const This, num_frames: usize, level: *LogRamp) void {
            std.debug.assert(num_frames <= size);
            var l: f32 = undefined;
            for (0..num_frames) |fr| {
                l = level.update();
                inline for (0..N) |ch| {
                    self.buf[ch][fr] += other.buf[ch][fr] * l;
                }
            }
        }

        pub fn mixFromSlice(self: *This, slice: []const f32, level: *LogRamp) void {
            std.debug.assert(slice.len <= size);
            var l: f32 = undefined;
            for (slice, 0..) |val, fr| {
                l = level.update();
                inline for (0..N) |ch| {
                    self.buf[ch][fr] += val * l;
                }
            }
        }

        pub fn panMixFrom(self: *This, other: *const Bus(1, size), num_frames: usize, level: *LogRamp, pan: *LogRamp) void {
            std.debug.assert(num_frames <= size);
            comptime {
                std.debug.assert(N > 1);
            }
            var l: f32 = undefined;
            var c: f32 = undefined;
            var x: f32 = undefined;
            for (0..num_frames) |fr| {
                x = other.buf[0][fr];
                l = level.update();
                c = pan.update();
                c *= std.math.pi / 2.0;
                self.buf[0][fr] += x * l * @cos(c);
                self.buf[1][fr] += x * l * @sin(c);
            }
        }
    };
}
