const std = @import("std");

const log001: f32 = -6.9078;
const tiny = std.math.pow(f32, 10, -15);
const huge = std.math.pow(f32, 10, 15);

inline fn zapgremlins(x: f32) f32 {
    const absx = @abs(x);
    return if (absx > tiny and absx < huge) x else 0;
}

// convert a time-to-convergence to a pole coefficient
// "ref" argument defines the amount of convergence
// target ratio is e^ref.
// -6.9 corresponds to standard -60db convergence
fn tau2pole(t: f32, sr: f32, ref: f32) f32 {
    return @exp(ref / (t * sr));
}

// one-pole lowpass smoother
// define this here for a consistent interpretation of pole coefficient
// we use faust's definition where b=0 is instant, b in [0, 1)
fn smooth1pole(x: f32, x0: f32, b: f32) f32 {
    return x + (x0 - x) * b;
}

pub const LogRamp = struct {
    sample_rate: f32 = 48000,
    time: f32 = 0.001,
    b: f32 = tau2pole(0.001, 48000, -6.9),
    x0: f32 = 0,
    y0: f32 = 0,

    pub fn create(sr: f32, t: f32) LogRamp {
        var ret: LogRamp = .{
            .sample_rate = sr,
            .time = t,
            .b = 1,
            .x = 0,
            .y0 = 0,
        };
        ret.recalculateB();
        return ret;
    }

    // needs to be called after time or sample rate are changed!
    pub fn recalculateB(self: *LogRamp) void {
        self.b = tau2pole(self.time, self.sample_rate, -6.9);
    }

    pub fn update(self: *LogRamp) f32 {
        self.y0 = smooth1pole(self.x0, self.y0, self.b);
        return self.y0;
    }

    pub fn process(self: *LogRamp, x: f32) f32 {
        self.x0 = x;
        return self.update();
    }
};
