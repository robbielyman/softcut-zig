const std = @import("std");
pub const c = @import("c.zig");

pub const Info = c.SF_INFO;

pub const Mode = enum { Read, Write, RDWR };
pub const Whence = enum { Set, Cur, End };

pub const Err = error{
    UnrecognisedFormat,
    System,
    MalformedFile,
    UnsupportedEncoding,
    Other,
};

pub fn unwrap(err: c_int) Err!void {
    return switch (err) {
        0 => {},
        1 => error.UnrecognisedFormat,
        2 => error.System,
        3 => error.MalformedFile,
        4 => error.UnsupportedEncoding,
        else => error.Other,
    };
}

pub const SndFile = struct {
    handle: *c.SNDFILE,

    pub fn open(path: [:0]const u8, mode: Mode, info: *Info) Err!SndFile {
        const sf_mode = switch (mode) {
            .Read => c.SFM_READ,
            .Write => c.SFM_WRITE,
            .RDWR => c.SFM_RDWR,
        };
        return .{
            .handle = c.sf_open(path.ptr, sf_mode, info) orelse {
                try unwrap(c.sf_error(null));
                return error.Other;
            },
        };
    }

    pub fn close(self: *SndFile) Err!void {
        try unwrap(c.sf_close(self.handle));
        self.* = undefined;
    }

    pub fn writeSync(self: SndFile) void {
        c.sf_write_sync(self.handle);
    }

    pub fn seek(self: SndFile, frames: i64, whence: Whence) Err!i64 {
        const wh = switch (whence) {
            .Set => c.SEEK_SET,
            .Cur => c.SEEK_CUR,
            .End => c.SEEK_END,
        };
        const err_or_offset = c.sf_seek(self.handle, frames, wh);
        if (err_or_offset == -1) {
            try unwrap(c.sf_error(self.handle));
            return error.Other;
        }
        return err_or_offset;
    }

    pub fn readFloats(self: SndFile, slice: []f32) Err!usize {
        const err_or_count = c.sf_read_float(self.handle, slice.ptr, @intCast(slice.len));
        if (err_or_count < 0) {
            try unwrap(c.sf_error(self.handle));
            return error.Other;
        }
        return @intCast(err_or_count);
    }

    pub fn writeFloats(self: SndFile, slice: []const f32) Err!void {
        const err_or_count = c.sf_write_float(self.handle, slice.ptr, @intCast(slice.len));
        if (err_or_count != @as(i64, @intCast(slice.len))) {
            try unwrap(c.sf_error(self.handle));
        }
    }
};

pub fn formatCheck(info: *const Info) bool {
    return c.sf_format_check(info);
}

test "bogus open" {
    var info: Info = undefined;
    try std.testing.expectError(error.System, SndFile.open("./blahblahblah.wav", .Read, &info));
}
