/// partial Zig interface to liblo's OSC server implementation.
/// full C API is avaiable via `c`.
pub const c = @import("c.zig");
const std = @import("std");

pub const Err = error{LibloFailure};

pub const LoType = enum { infinity, nil };

pub fn sendMessage(target: Address, path: [*:0]const u8, msg: Message) Err!void {
    if (c.lo_send_message(target.handle, path, msg.handle) < 0) return error.LibloFailure;
}

pub const Message = struct {
    handle: c.lo_message,

    pub fn new() Message {
        return .{
            .handle = c.lo_message_new(),
        };
    }

    pub fn free(self: *Message) void {
        c.lo_message_free(self.handle);
        self.* = undefined;
    }

    pub fn clone(other: Message) Message {
        return .{
            .handle = c.lo_message_clone(other.handle),
        };
    }

    /// add a tuple of one or more arguments to the message
    /// will attempt to add integer and float literals as i32 and f32, respectively
    pub fn add(self: Message, args: anytype) Err!void {
        const info = @typeInfo(@TypeOf(args));
        std.debug.assert(info == .Struct);
        std.debug.assert(info.Struct.is_tuple);
        std.debug.assert(info.Struct.fields.len > 0);
        inline for (info.Struct.fields, 0..) |arg, i| {
            const arg_info = @typeInfo(@TypeOf(args[i]));
            if (arg_info == .Pointer) {
                const child = @typeInfo(arg_info.Pointer.child);
                if (child == .Array and child.Array.child == u8) {
                    const slice: [:0]const u8 = args[i];
                    if (c.lo_message_add_string(self.handle, slice.ptr) < 0) return error.LibloFailure;
                    continue;
                }
            }
            switch (arg.type) {
                i32 => if (c.lo_message_add_int32(self.handle, args[i]) < 0) return error.LibloFailure,
                i64 => if (c.lo_message_add_int64(self.handle, args[i]) < 0) return error.LibloFailure,
                f32 => if (c.lo_message_add_float(self.handle, args[i]) < 0) return error.LibloFailure,
                f64 => if (c.lo_message_add_double(self.handle, args[i]) < 0) return error.LibloFailure,
                [:0]u8, [:0]const u8 => if (c.lo_message_add_string(self.handle, args[i].ptr) < 0) return error.LibloFailure,
                [*:0]u8, [*:0]const u8 => if (c.lo_message_add_string(self.handle, args[i]) < 0) return error.LibloFailure,
                Blob => if (c.lo_message_add_blob(self.handle, args[i].handle) < 0) return error.LibloFailure,
                u8 => if (c.lo_message_add_char(self.handle, args[i]) < 0) return error.LibloFailure,
                bool => {
                    if (args[i]) {
                        if (c.lo_message_add_true(self.handle) < 0) return error.LibloFailure;
                    } else {
                        if (c.lo_message_add_false(self.handle) < 0) return error.LibloFailure;
                    }
                },
                [4]u8 => if (c.lo_message_add_midi(self.handle, &args[i]) < 0) return error.LibloFailure,
                LoType => {
                    switch (args[i]) {
                        .infinity => if (c.lo_message_add_infinitum(self.handle) < 0) return error.LibloFailure,
                        .nil => if (c.lo_message_add_nil(self.handle) < 0) return error.LibloFailure,
                    }
                },
                @TypeOf(null) => if (c.lo_message_add_nil(self.handle) < 0) return error.LibloFailure,
                comptime_int => {
                    const as_i32: i32 = @intCast(args[i]);
                    if (c.lo_message_add_int32(self.handle, as_i32) < 0) return error.LibloFailure;
                },
                comptime_float => {
                    const as_f32: f32 = @floatCast(args[i]);
                    if (c.lo_message_add_float(self.handle, as_f32) < 0) return error.LibloFailure;
                },
                @TypeOf(.enum_literal) => {
                    if (args[i] == .infinity) {
                        if (c.lo_message_add_infinitum(self.handle) < 0) return error.LibloFailure;
                    } else if (args[i] == .nil) {
                        if (c.lo_message_add_nil(self.handle) < 0) return error.LibloFailure;
                    } else {
                        @compileError("Message.add called with unexpected enum literal: " ++ @tagName(args[i]) ++ "'");
                    }
                },
                else => {
                    @compileError("Message.add called with unsupported type: '" ++ @typeName(arg.type) ++ "'");
                },
            }
        }
    }

    pub const GetArgErr = Err || error{ BadType, OutOfBounds };
    pub fn getArg(self: Message, comptime T: type, index: usize) GetArgErr!T {
        const len = self.argCount();
        if (index >= len) return error.OutOfBounds;
        const msg_types = try self.types();
        const args = self.argValues() orelse return error.LibloFailure;
        const kind = msg_types[index];
        switch (T) {
            i32 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 'i') return error.BadType;
                return arg.i;
            },
            i64 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 'h') {
                    if (kind != 'i') return error.BadType;
                    return arg.i;
                }
                return arg.h;
            },
            f32 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 'f') {
                    if (kind != 'd') return error.BadType;
                    return @floatCast(arg.d);
                }
                return arg.f;
            },
            f64 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 'd') {
                    if (kind != 'f') return error.BadType;
                    return @floatCast(arg.f);
                }
                return arg.d;
            },
            [*:0]const u8, [*]const u8 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 's') {
                    if (kind != 'S') return error.BadType;
                    return @ptrCast(&arg.S);
                }
                return @ptrCast(&arg.s);
            },
            [:0]const u8, []const u8 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 's') {
                    if (kind != 'S') return error.BadType;
                    const ptr: [*:0]const u8 = @ptrCast(&arg.S);
                    return std.mem.sliceTo(ptr, 0);
                }
                const ptr: [*:0]const u8 = @ptrCast(&arg.s);
                return std.mem.sliceTo(ptr, 0);
            },
            [4]u8 => {
                const arg = args[index] orelse return error.LibloFailure;
                if (kind != 'm') return error.BadType;
                return arg.m;
            },
            LoType => {
                if (kind != 'N') {
                    if (kind != 'I') return error.BadType;
                    return @as(LoType, .infinity);
                }
                return @as(LoType, .nil);
            },
            bool => {
                if (kind == 'T') return true;
                if (kind == 'F') return false;
                return error.BadType;
            },
            else => @compileError("Message.getArg called with unsupported type: '" ++ @typeName(T) ++ "'"),
        }
    }

    pub fn source(self: Message) Address {
        return .{
            .handle = c.lo_message_get_source(self.handle),
        };
    }

    pub fn types(self: Message) Err![*:0]const u8 {
        return @ptrCast(c.lo_message_get_types(self.handle) orelse return error.LibloFailure);
    }

    pub fn argCount(self: Message) usize {
        return @intCast(c.lo_message_get_argc(self.handle));
    }

    pub fn argValues(self: Message) ?[*]?*c.lo_arg {
        return c.lo_message_get_argv(self.handle);
    }

    pub fn length(self: Message, path: [*:0]const u8) usize {
        return c.lo_message_length(self.handle, path);
    }

    test "ref" {
        std.testing.refAllDecls(Message);
    }
};

pub const Address = struct {
    handle: c.lo_address,

    pub fn new(host: [*:0]const u8, port_number: [*:0]const u8) Address {
        return .{
            .handle = c.lo_address_new(host, port_number),
        };
    }

    pub fn free(self: *Address) void {
        c.lo_address_free(self.handle);
        self.* = undefined;
    }

    pub fn hostname(self: Address) Err![*:0]const u8 {
        return c.lo_address_get_hostname(self.handle) orelse return error.LibloFailure;
    }

    pub fn port(self: Address) Err![*:0]const u8 {
        return c.lo_address_get_port(self.handle) orelse return error.LibloFailure;
    }
};

pub const Blob = struct {
    handle: c.lo_blob,

    pub fn newFromBytes(bytes: []const u8) Blob {
        return .{
            .handle = c.lo_blob_new(@intCast(bytes.len), bytes.ptr),
        };
    }

    pub fn free(self: *Blob) void {
        c.lo_blob_free(self.handle);
        self.* = undefined;
    }

    pub fn size(self: Blob) usize {
        return c.lo_blob_datasize(self.handle);
    }

    pub fn ptr(self: Blob) [*]u8 {
        return c.lo_blob_dataptr(self.handle);
    }

    pub fn byteSlice(self: Blob) []u8 {
        const len = self.size();
        return self.ptr()[0..len];
    }
};

pub const ServerThread = struct {
    handle: c.lo_server_thread,

    pub fn new(port: [*:0]const u8, handler: ?*const CErrFn) ServerThread {
        return .{
            .handle = c.lo_server_thread_new(port, handler),
        };
    }

    pub fn free(self: *ServerThread) void {
        c.lo_server_thread_free(self.handle);
        self.* = undefined;
    }

    pub fn start(self: ServerThread) Err!void {
        if (c.lo_server_thread_start(self.handle) < 0) return error.LibloFailure;
    }

    pub fn stop(self: ServerThread) Err!void {
        if (c.lo_server_thread_stop(self.handle) < 0) return error.LibloFailure;
    }

    pub fn addMethod(self: ServerThread, path: ?[*:0]const u8, typespec: ?[*:0]const u8, method: *const CMethodFn, user_data: ?*const anyopaque) Method {
        return .{
            .handle = c.lo_server_thread_add_method(self.handle, path, typespec, method, user_data),
        };
    }

    pub fn deleteMethod(self: ServerThread, method: Method) Err!void {
        if (c.lo_server_del_lo_method(self.handle, method.handle) < 0) return error.LibloFailure;
    }
};

pub const Method = struct {
    handle: c.lo_method,
};

pub const CErrFn = fn (c_int, [*c]const u8, [*c]const u8) callconv(.C) void;
pub const CMethodFn = fn ([*c]const u8, [*c]const u8, [*c][*c]c.lo_arg, c_int, c.lo_message, ?*anyopaque) callconv(.C) c_int;

pub const ErrFn = fn (errno: i32, msg: [*:0]const u8, where: [*:0]const u8) void;
pub const MethodFn = fn (path: [*:0]const u8, msg: Message, ctx: ?*anyopaque) bool;

pub fn wrap(comptime function: anytype) TypeOfWrap(@TypeOf(function)) {
    const T = @TypeOf(function);
    return switch (T) {
        ErrFn => wrapErrFn(function),
        MethodFn => wrapMethodFn(function),
        else => @compileError("unsupported type given to wrap: '" ++ @typeName(T) ++ "'"),
    };
}

fn TypeOfWrap(comptime T: type) type {
    return switch (T) {
        ErrFn => CErrFn,
        MethodFn => CMethodFn,
        else => @compileError("unsupported type given to wrap: '" ++ @typeName(T) ++ "'"),
    };
}

fn wrapErrFn(comptime f: ErrFn) CErrFn {
    return struct {
        fn inner(errno: c_int, msg: [*c]const u8, where: [*c]const u8) callconv(.C) void {
            const err_no: i32 = @intCast(errno);
            const msg_ptr: [*:0]const u8 = msg.?;
            const where_ptr: [*:0]const u8 = where.?;
            @call(.always_inline, f, .{ err_no, msg_ptr, where_ptr });
        }
    }.inner;
}

fn wrapMethodFn(comptime f: MethodFn) CMethodFn {
    return struct {
        fn inner(
            path: [*c]const u8,
            types: [*c]const u8,
            argv: [*c][*c]c.lo_arg,
            argc: c_int,
            msg: c.lo_message,
            user_data: ?*anyopaque,
        ) callconv(.C) c_int {
            _ = argc; // autofix
            _ = types; // autofix
            _ = argv; // autofix
            const path_ptr: [*:0]const u8 = path.?;
            const message: Message = .{ .handle = msg };
            return if (@call(.always_inline, f, .{ path_ptr, message, user_data })) 1 else 0;
        }
    }.inner;
}

test "message new" {
    var msg = Message.new();
    defer msg.free();
    try msg.add(.{ 4, 4.5, "hey, hi, hello", .infinity, .nil, null, false, true });
    try std.testing.expectEqualStrings("ifsINNFT", std.mem.sliceTo(try msg.types(), 0));
    try std.testing.expectEqual(8, msg.argCount());
    _ = msg.argValues();
    _ = msg.length("/bogus/path");
    try std.testing.expectEqual(4, try msg.getArg(i32, 0));
    try std.testing.expectEqualStrings("hey, hi, hello", try msg.getArg([]const u8, 2));
    try std.testing.expectEqual(4.5, try msg.getArg(f32, 1));
    try std.testing.expectEqual(.infinity, try msg.getArg(LoType, 3));
    try std.testing.expectEqual(.nil, try msg.getArg(LoType, 4));
    try std.testing.expectEqual(.nil, try msg.getArg(LoType, 5));
    try std.testing.expectEqual(false, try msg.getArg(bool, 6));
    try std.testing.expectEqual(true, try msg.getArg(bool, 7));
}

test "C include" {
    _ = c;
    _ = Message;
    _ = Blob;
    _ = Address;
    _ = ServerThread;
}
