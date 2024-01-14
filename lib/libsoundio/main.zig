/// partial Zig interface to libsoundio
/// full C api is available via `c`.
pub const c = @import("c.zig");
const std = @import("std");

pub const Format = enum(c_int) {
    Invalid = c.SoundIoFormatInvalid,
    S8 = c.SoundIoFormatS8,
    U8 = c.SoundIoFormatU8,
    S16LE = c.SoundIoFormatS16LE,
    S16BE = c.SoundIoFormatS16BE,
    S16NE = c.SoundIoFormatS16NE,
    U16LE = c.SoundIoFormatU16LE,
    U16BE = c.SoundIoFormatU16BE,
    U16NE = c.SoundIoFormatU16NE,
    S24LE = c.SoundIoFormatS24LE,
    S24BE = c.SoundIoFormatS24BE,
    S24NE = c.SoundIoFormatS24NE,
    U24LE = c.SoundIoFormatU24LE,
    U24BE = c.SoundIoFormatU24BE,
    U24NE = c.SoundIoFormatU24NE,
    S32LE = c.SoundIoFormatS32LE,
    S32BE = c.SoundIoFormatS32BE,
    S32NE = c.SoundIoFormatS32NE,
    U32LE = c.SoundIoFormatU32LE,
    U32BE = c.SoundIoFormatU32BE,
    U32NE = c.SoundIoFormatU32NE,
    Float32LE = c.SoundIoFormatFloat32LE,
    Float32BE = c.SoundIoFormatFloat32BE,
    Float32NE = c.SoundIoFormatFloat32NE,
    Float64LE = c.SoundIoFormatFloat64LE,
    Float64BE = c.SoundIoFormatFloat64BE,
    Float64NE = c.SoundIoFormatFloat64NE,
};

pub const LayoutId = enum(c_int) {
    IdMono = c.SoundIoChannelLayoutIdMono,
    IdStereo = c.SoundIoChannelLayoutIdStereo,
    Id2Point1 = c.SoundIoChannelLayoutId2Point1,
    Id3Point0 = c.SoundIoChannelLayoutId3Point0,
    Id3Point0Back = c.SoundIoChannelLayoutId3Point0Back,
    Id3Point1 = c.SoundIoChannelLayoutId3Point1,
    Id4Point0 = c.SoundIoChannelLayoutId4Point0,
    IdQuad = c.SoundIoChannelLayoutIdQuad,
    IdQuadSide = c.SoundIoChannelLayoutIdQuadSide,
    Id4Point1 = c.SoundIoChannelLayoutId4Point1,
    Id5Point0Back = c.SoundIoChannelLayoutId5Point0Back,
    Id5Point0Side = c.SoundIoChannelLayoutId5Point0Side,
    Id5Point1 = c.SoundIoChannelLayoutId5Point1,
    Id5Point1Back = c.SoundIoChannelLayoutId5Point1Back,
    Id6Point0Side = c.SoundIoChannelLayoutId6Point0Side,
    Id6Point0Front = c.SoundIoChannelLayoutId6Point0Front,
    IdHexagonal = c.SoundIoChannelLayoutIdHexagonal,
    Id6Point1 = c.SoundIoChannelLayoutId6Point1,
    Id6Point1Back = c.SoundIoChannelLayoutId6Point1Back,
    Id6Point1Front = c.SoundIoChannelLayoutId6Point1Front,
    Id7Point0 = c.SoundIoChannelLayoutId7Point0,
    Id7Point0Front = c.SoundIoChannelLayoutId7Point0Front,
    Id7Point1 = c.SoundIoChannelLayoutId7Point1,
    Id7Point1Wide = c.SoundIoChannelLayoutId7Point1Wide,
    Id7Point1Back = c.SoundIoChannelLayoutId7Point1Back,
    IdOctagonal = c.SoundIoChannelLayoutIdOctagonal,
};

pub const ChannelId = enum(c_int) {
    Invalid = c.SoundIoInvalid,
    FrontLeft = c.SoundIoFrontLeft,
    FrontRight = c.SoundIoFrontRight,
    FrontCenter = c.SoundIoFrontCenter,
    Lfe = c.SoundIoLfe,
    BackLeft = c.SoundIoBackLeft,
    BackRight = c.SoundIoBackRight,
    FrontLeftCenter = c.SoundIoFrontLeftCenter,
    FrontRightCenter = c.SoundIoFrontRightCenter,
    BackCenter = c.SoundIoBackCenter,
    SideLeft = c.SoundIoSideLeft,
    SideRight = c.SoundIoSideRight,
    TopCenter = c.SoundIoTopCenter,
    TopFrontLeft = c.SoundIoTopFrontLeft,
    TopFrontCenter = c.SoundIoTopFrontCenter,
    TopFrontRight = c.SoundIoTopFrontRight,
    TopBackLeft = c.SoundIoTopBackLeft,
    TopBackCenter = c.SoundIoTopBackCenter,
    TopBackRight = c.SoundIoTopBackRight,
    BackLeftCenter = c.SoundIoBackLeftCenter,
    BackRightCenter = c.SoundIoBackRightCenter,
    FrontLeftWide = c.SoundIoFrontLeftWide,
    FrontRightWide = c.SoundIoFrontRightWide,
    FrontLeftHigh = c.SoundIoFrontLeftHigh,
    FrontCenterHigh = c.SoundIoFrontCenterHigh,
    FrontRightHigh = c.SoundIoFrontRightHigh,
    TopFrontLeftCenter = c.SoundIoTopFrontLeftCenter,
    TopFrontRightCenter = c.SoundIoTopFrontRightCenter,
    TopSideLeft = c.SoundIoTopSideLeft,
    TopSideRight = c.SoundIoTopSideRight,
    LeftLfe = c.SoundIoLeftLfe,
    RightLfe = c.SoundIoRightLfe,
    Lfe2 = c.SoundIoLfe2,
    BottomCenter = c.SoundIoBottomCenter,
    BottomLeftCenter = c.SoundIoBottomLeftCenter,
    BottomRightCenter = c.SoundIoBottomRightCenter,
    MsMid = c.SoundIoMsMid,
    MsSide = c.SoundIoMsSide,
    AmbisonicW = c.SoundIoAmbisonicW,
    AmbisonicX = c.SoundIoAmbisonicX,
    AmbisonicY = c.SoundIoAmbisonicY,
    AmbisonicZ = c.SoundIoAmbisonicZ,
    XyX = c.SoundIoXyX,
    XyY = c.SoundIoXyY,
    HeadphonesLeft = c.SoundIoHeadphonesLeft,
    HeadphonesRight = c.SoundIoHeadphonesRight,
    ClickTrack = c.SoundIoClickTrack,
    ForeignLanguage = c.SoundIoForeignLanguage,
    HearingImpaired = c.SoundIoHearingImpaired,
    Narration = c.SoundIoNarration,
    Haptic = c.SoundIoHaptic,
    DialogCentricMix = c.SoundIoDialogCentricMix,
    Aux = c.SoundIoAux,
    Aux0 = c.SoundIoAux0,
    Aux1 = c.SoundIoAux1,
    Aux2 = c.SoundIoAux2,
    Aux3 = c.SoundIoAux3,
    Aux4 = c.SoundIoAux4,
    Aux5 = c.SoundIoAux5,
    Aux6 = c.SoundIoAux6,
    Aux7 = c.SoundIoAux7,
    Aux8 = c.SoundIoAux8,
    Aux9 = c.SoundIoAux9,
    Aux10 = c.SoundIoAux10,
    Aux11 = c.SoundIoAux11,
    Aux12 = c.SoundIoAux12,
    Aux13 = c.SoundIoAux13,
    Aux14 = c.SoundIoAux14,
    Aux15 = c.SoundIoAux15,
};

pub const Err = error{
    OutOfMemory,
    InitAudioBackend,
    SystemResources,
    OpeningDevice,
    NoSuchDevice,
    Invalid,
    BackendUnavailable,
    Streaming,
    IncompatibleDevice,
    NoSuchClient,
    IncompatibleBackend,
    BackendDisconnected,
    Interrupted,
    Underflow,
    EncodingString,
    Unknown,
};

pub fn unwrap(err: c_int) Err!void {
    return switch (err) {
        c.SoundIoErrorNone => {},
        c.SoundIoErrorNoMem => error.OutOfMemory,
        c.SoundIoErrorInitAudioBackend => error.InitAudioBackend,
        c.SoundIoErrorSystemResources => error.SystemResources,
        c.SoundIoErrorOpeningDevice => error.OpeningDevice,
        c.SoundIoErrorNoSuchDevice => error.NoSuchDevice,
        c.SoundIoErrorInvalid => error.Invalid,
        c.SoundIoErrorBackendUnavailable => error.BackendUnavailable,
        c.SoundIoErrorStreaming => error.Streaming,
        c.SoundIoErrorIncompatibleDevice => error.IncompatibleDevice,
        c.SoundIoErrorNoSuchClient => error.NoSuchClient,
        c.SoundIoErrorIncompatibleBackend => error.IncompatibleBackend,
        c.SoundIoErrorBackendDisconnected => error.BackendDisconnected,
        c.SoundIoErrorInterrupted => error.Interrupted,
        c.SoundIoErrorUnderflow => error.Underflow,
        c.SoundIoErrorEncodingString => error.EncodingString,
        else => error.Unknown,
    };
}

const SoundIo = struct {
    handle: *c.SoundIo,

    pub fn create() Err!SoundIo {
        return .{
            .handle = c.soundio_create() orelse return error.OutOfMemory,
        };
    }

    pub fn connect(self: SoundIo) Err!void {
        try unwrap(c.soundio_connect(self.handle));
    }

    pub fn disconnect(self: SoundIo) void {
        c.soundio_disconnect(self.handle);
    }

    pub fn destroy(self: *SoundIo) void {
        c.soundio_destroy(self.handle);
        self.* = undefined;
    }

    pub fn flushEvents(self: SoundIo) void {
        c.soundio_flush_events(self.handle);
    }

    pub fn waitEvents(self: SoundIo) void {
        c.soundio_wait_events(self.handle);
    }

    pub fn wakeup(self: SoundIo) void {
        c.soundio_wakeup(self.handle);
    }

    pub fn forceDeviceScan(self: SoundIo) void {
        c.soundio_force_device_scan(self.handle);
    }

    pub fn inputDeviceCount(self: SoundIo) Err!usize {
        const count = c.soundio_input_device_count(self.handle);
        return if (count == -1) error.Invalid else @intCast(count);
    }

    pub fn outputDeviceCount(self: SoundIo) Err!usize {
        const count = c.soundio_output_device_count(self.handle);
        return if (count == -1) error.Invalid else @intCast(count);
    }

    pub fn defaultInputDeviceIndex(self: SoundIo) Err!usize {
        const index = c.soundio_default_input_device_index(self.handle);
        return if (index == -1) error.Invalid else @intCast(index);
    }

    pub fn defaultOutputDeviceIndex(self: SoundIo) Err!usize {
        const index = c.soundio_default_output_device_index(self.handle);
        return if (index == -1) error.Invalid else @intCast(index);
    }

    pub fn getInputDevice(self: SoundIo, index: usize) Err!Device {
        return .{
            .handle = c.soundio_get_input_device(self.handle, @intCast(index)) orelse return error.Invalid,
        };
    }

    pub fn getOutputDevice(self: SoundIo, index: usize) Err!Device {
        return .{
            .handle = c.soundio_get_output_device(self.handle, @intCast(index)) orelse return error.Invalid,
        };
    }

    test "create and destroy" {
        var soundio = try SoundIo.create();
        defer soundio.destroy();
        try soundio.connect();
        defer soundio.disconnect();
        soundio.flushEvents();
        std.log.info("{d}", .{try soundio.outputDeviceCount()});
        std.log.info("{d}", .{try soundio.inputDeviceCount()});
    }
};

pub const Device = struct {
    handle: *c.SoundIoDevice,

    pub fn eql(a: Device, b: Device) bool {
        return c.soundio_device_equal(a.handle, b.handle);
    }

    pub fn ref(self: Device) void {
        c.soundio_device_ref(self.handle);
    }

    pub fn unref(self: Device) void {
        c.soundio_device_unref(self.handle);
    }

    pub fn nearestSampleRate(self: Device, rate: usize) usize {
        return @intCast(c.soundio_device_nearest_sample_rate(self.handle, @intCast(rate)));
    }

    pub fn sortChannelLayouts(self: Device) void {
        c.soundio_device_sort_channel_layouts(self.handle);
    }

    pub fn supportsFormat(self: Device, format: Format) bool {
        return c.soundio_device_supports_format(self.handle, @intFromEnum(format));
    }

    pub fn supportsLayout(self: Device, layout: *c.SoundIoChannelLayout) bool {
        return c.soundio_device_supports_layout(self.handle, layout);
    }

    pub fn supportsSampleRate(self: Device, rate: usize) bool {
        return c.soundio_device_supports_sample_rate(self.handle, @intCast(rate));
    }

    pub fn createOutStream(self: Device) Err!OutStream {
        return .{
            .handle = c.soundio_outstream_create(self.handle) orelse return error.OutOfMemory,
        };
    }

    pub fn createInStream(self: Device) Err!InStream {
        return .{
            .handle = c.soundio_instream_create(self.handle) orelse return error.OutOfMemory,
        };
    }
};

pub const OutStream = struct {
    handle: *c.SoundIoOutStream,

    pub fn destroy(self: *OutStream) void {
        c.soundio_outstream_destroy(self.handle);
        self.* = undefined;
    }

    pub fn open(self: OutStream) Err!void {
        try unwrap(c.soundio_outstream_open(self.handle));
    }

    pub fn start(self: OutStream) Err!void {
        try unwrap(c.soundio_outstream_start(self.handle));
    }

    pub fn beginWrite(self: OutStream, areas: [*]?*c.SoundIoChannelArea, frame_count: usize) Err!usize {
        var count: c_int = @intCast(frame_count);
        try unwrap(c.soundio_outstream_begin_write(self.handle, areas, &count));
        return @intCast(count);
    }

    pub fn clearBuffer(self: OutStream) Err!void {
        try unwrap(c.soundio_outstream_clear_buffer(self.handle));
    }

    pub fn endWrite(self: OutStream) Err!void {
        try unwrap(c.soundio_outstream_end_write(self.handle));
    }

    pub fn getLatency(self: OutStream) Err!f64 {
        var val: f64 = undefined;
        try unwrap(c.soundio_outstream_get_latency(self.handle, &val));
        return val;
    }

    pub fn pause(self: OutStream, pause_state: bool) Err!void {
        try unwrap(c.soundio_outstream_pause(self.handle, pause_state));
    }

    pub fn setVolume(self: OutStream, volume: f64) Err!void {
        try unwrap(c.soundio_outstream_set_volume(self.handle, volume));
    }
};

pub const InStream = struct {
    handle: *c.SoundIoInStream,

    pub fn destroy(self: *InStream) void {
        c.soundio_instream_destroy(self.handle);
        self.* = undefined;
    }

    pub fn open(self: InStream) Err!void {
        try unwrap(c.soundio_instream_open(self.handle));
    }

    pub fn start(self: InStream) Err!void {
        try unwrap(c.soundio_instream_start(self.handle));
    }

    pub fn beginRead(self: InStream, areas: ?[*]?*c.SoundIoChannelArea, frame_count: usize) Err!usize {
        var count: c_int = @intCast(frame_count);
        try unwrap(c.soundio_instream_begin_read(self.handle, areas, &count));
        return @intCast(count);
    }

    pub fn endRead(self: InStream) Err!void {
        try unwrap(c.soundio_instream_end_read(self.handle));
    }

    pub fn getLatency(self: InStream) Err!f64 {
        var val: f64 = undefined;
        try unwrap(c.soundio_instream_get_latency(self.handle, &val));
        return val;
    }

    pub fn pause(self: InStream, pause_state: bool) Err!void {
        try unwrap(c.soundio_instream_pause(self.handle, pause_state));
    }
};

pub const RingBuffer = struct {
    handle: *c.SoundIoRingBuffer,

    pub fn create(context: SoundIo, requested_capacity: usize) Err!RingBuffer {
        return .{
            .handle = c.soundio_ring_buffer_create(context.handle, @intCast(requested_capacity)) orelse return error.OutOfMemory,
        };
    }

    pub fn destroy(self: *RingBuffer) void {
        c.soundio_ring_buffer_destroy(self.handle);
        self.* = undefined;
    }

    pub fn fillCount(self: RingBuffer) usize {
        return @intCast(c.soundio_ring_buffer_fill_count(self.handle));
    }

    pub fn freeCount(self: RingBuffer) usize {
        return @intCast(c.soundio_ring_buffer_fill_count(self.handle));
    }

    pub fn readPtr(self: RingBuffer) [*]const u8 {
        return c.soundio_ring_buffer_read_ptr(self.handle).?;
    }

    pub fn writePtr(self: RingBuffer) [*]u8 {
        return c.soundio_ring_buffer_write_ptr(self.handle).?;
    }

    pub fn clear(self: RingBuffer) void {
        c.soundio_ring_buffer_clear(self.handle);
    }

    pub fn capacity(self: RingBuffer) usize {
        return @intCast(c.soundio_ring_buffer_capacity(self.handle));
    }

    pub fn advanceReadPtr(self: RingBuffer, count: usize) void {
        c.soundio_ring_buffer_advance_read_ptr(self.handle, @intCast(count));
    }

    pub fn advanceWritePtr(self: RingBuffer, count: usize) void {
        c.soundio_ring_buffer_advance_write_ptr(self.handle, @intCast(count));
    }
};

test "C include" {
    _ = c;
    _ = SoundIo;
}
