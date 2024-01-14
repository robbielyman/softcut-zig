const Client = @import("client.zig");

const This = @This();

quit: bool = true,

pub fn init(softcut: *const Client) !This {
    _ = softcut; // autofix
    return .{};
}

pub fn deinit(this: *const This) void {
    _ = this; // autofix
}
