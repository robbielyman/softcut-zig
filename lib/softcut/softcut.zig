const std = @import("std");

pub fn Softcut(comptime voices: usize) type {
    var buf: [10]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .{
        .buffer = &buf,
        .end_index = 0,
    };
    const voices_str = try std.fmt.allocPrint(fba.allocator(), "{d}", .{voices});

    const c = @cImport({
        @cDefine("SOFTCUT_C_NUMVOICES", voices_str);
        @cInclude("softcut_c.h");
    });
    return struct {
        handle: *c.softcut_t,

        pub const Err = error{VoiceOutOfBounds};

        const This = @This();
        pub fn init() !This {
            return .{
                .handle = c.softcut_init() orelse return error.Failed,
            };
        }

        pub fn destroy(self: *This) void {
            c.softcut_destroy(self.handle);
        }

        pub fn reset(self: This) void {
            c.softcut_reset(self.handle);
        }

        pub fn processBlock(self: This, voice: usize, in: []const f32, out: []f32) (error{BadSliceSize} || Err)!void {
            if (in.len != out.len) return error.BadSliceSize;
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_process_block(self.handle, @intCast(voice), in.ptr, out.ptr, @intCast(in.len));
        }

        pub fn setSampleRate(self: This, hz: u32) void {
            c.softcut_set_samplerate(self.handle, hz);
        }

        pub fn setRate(self: This, voice: usize, rate: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rate(self.handle, @intCast(voice), rate);
        }

        pub fn setLoopStart(self: This, voice: usize, sec: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_loop_start(self.handle, @intCast(voice), sec);
        }

        pub fn setLoopEnd(self: This, voice: usize, sec: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_loop_end(self.handle, @intCast(voice), sec);
        }

        pub fn setLoopFlag(self: This, voice: usize, flag: bool) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_loop_flag(self.handle, @intCast(voice), flag);
        }

        pub fn setFadeTime(self: This, voice: usize, sec: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_fade_time(self.handle, @intCast(voice), sec);
        }

        pub fn setRecLevel(self: This, voice: usize, amp: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rec_level(self.handle, @intCast(voice), amp);
        }

        pub fn setPreLevel(self: This, voice: usize, amp: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_level(self.handle, @intCast(voice), amp);
        }

        pub fn setRecFlag(self: This, voice: usize, flag: bool) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rec_flag(self.handle, @intCast(voice), flag);
        }

        pub fn setRecOnceFlag(self: This, voice: usize, flag: bool) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rec_once_flag(self.handle, @intCast(voice), flag);
        }

        pub fn setPlayFlag(self: This, voice: usize, flag: bool) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_play_flag(self.handle, @intCast(voice), flag);
        }

        pub fn cutToPos(self: This, voice: usize, sec: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_cut_to_pos(self.handle, @intCast(voice), sec);
        }

        pub fn setPreFilterFc(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_fc(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterRq(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_rq(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterLp(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_lp(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterHp(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_hp(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterBp(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_bp(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterBr(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_br(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterDry(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_dry(self.handle, @intCast(voice), x);
        }

        pub fn setPreFilterFcMod(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_pre_filter_fc_mod(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterFc(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_fc(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterRq(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_rq(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterLp(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_lp(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterHp(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_hp(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterBp(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_bp(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterBr(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_br(self.handle, @intCast(voice), x);
        }

        pub fn setPostFilterDry(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_post_filter_dry(self.handle, @intCast(voice), x);
        }

        pub fn setRecOffset(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rec_offset(self.handle, @intCast(voice), x);
        }

        pub fn setRecPreSlewTime(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rec_pre_slew_time(self.handle, @intCast(voice), x);
        }

        pub fn setRateSlewTime(self: This, voice: usize, x: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_rate_slew_time(self.handle, @intCast(voice), x);
        }

        pub fn getQuantPhase(self: This, voice: usize) Err!f64 {
            if (voice >= voices) return error.VoiceOutOfBounds;
            return c.softcut_get_quant_phase(self.handle, @intCast(voice));
        }

        pub fn setPhaseQuant(self: This, voice: usize, quant: f64) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_phase_quant(self.handle, @intCast(voice), quant);
        }

        pub fn setPhaseOffset(self: This, voice: usize, sec: f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_phase_offset(self.handle, @intCast(voice), sec);
        }

        pub fn getRecFlag(self: This, voice: usize) Err!bool {
            if (voice >= voices) return error.VoiceOutOfBounds;
            return c.softcut_get_rec_flag(self.handle, @intCast(voice));
        }

        pub fn getPlayFlag(self: This, voice: usize) Err!bool {
            if (voice >= voices) return error.VoiceOutOfBounds;
            return c.softcut_get_play_flag(self.handle, @intCast(voice));
        }

        pub fn syncVoice(self: This, follow: usize, lead: usize, offset: f32) Err!void {
            if (follow >= voices or lead >= voices) return error.VoiceOutOfBounds;
            c.softcut_sync_voice(self.handle, @intCast(follow), @intCast(lead), offset);
        }

        pub fn setVoiceBuffer(self: This, voice: usize, buffer: []f32) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_set_voice_buffer(self.handle, @intCast(voice), buffer.ptr, buffer.len);
        }

        pub fn getSavedPosition(self: This, voice: usize) Err!f32 {
            if (voice >= voices) return error.VoiceOutOfBounds;
            return c.softcut_get_saved_position(self.handle, @intCast(voice));
        }

        pub fn stopVoice(self: This, voice: usize) Err!void {
            if (voice >= voices) return error.VoiceOutOfBounds;
            c.softcut_stop_voice(self.handle, @intCast(voice));
        }
    };
}

test {
    const sc = Softcut(6);
    std.testing.refAllDecls(sc);
    const softcut = sc.init();
    defer softcut.destroy();
    softcut.reset();
}
