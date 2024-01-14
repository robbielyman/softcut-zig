const std = @import("std");
const numVoices = @import("options").voices;
const sc = @import("softcut").Softcut(numVoices);

const maxBlockFrames: usize = 2048;
const bufFrames: usize = 2 << 24;

const This = @This();

cut: sc,
buf: [2][bufFrames]f32,
enabled: [numVoices]bool,
quantPhase: [numVoices]f64,
sampleRate: f32,

// caller owns created memory.
pub fn create(allocator: std.mem.Allocator) !*This {
    const this = try allocator.create(This);
    this.cut = sc.init();
    for (0..numVoices) |i| {
        try this.cut.setVoiceBuffer(i, &this.buf[i % 2]);
    }
    return this;
}

pub fn setup(self: *This) !void {
    _ = self; // autofix
}

pub fn cleanup(self: *This) void {
    self.cut.destroy();
}

pub fn start(self: *This) !void {
    _ = self; // autofix
}

pub fn stop(self: *This) void {
    _ = self; // autofix
}

pub fn connectInputs(self: *This) !void {
    _ = self; // autofix
}

pub fn connectOutputs(self: *This) !void {
    _ = self; // autofix
}
