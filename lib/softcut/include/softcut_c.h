//
// softcut C bindings
// written by rylee alanza lyman on 01/13/24.
//
#ifndef SOFTCUT_C_H
#define SOFTCUT_C_H

#ifndef SOFTCUT_C_NUMVOICES
#define SOFTCUT_C_NUMVOICES 6
#endif

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

struct softcut_t {
     void* ptr;
};

typedef struct softcut_t* Softcut;
typedef double phase_t;

Softcut softcut_init();

void softcut_destroy(Softcut self);
void softcut_reset(Softcut self);

void softcut_process_block(Softcut self, int v, const float *in, float *out, int numFrames);
void softcut_set_samplerate(Softcut self, unsigned int hz);
void softcut_set_rate(Softcut self, int voice, float rate);

void softcut_set_loop_start(Softcut self, int voice, float sec);
void softcut_set_loop_end(Softcut self, int voice, float sec);
void softcut_set_loop_flag(Softcut self, int voice, bool flag);

void softcut_set_fade_time(Softcut self, int voice, float sec);

void softcut_set_rec_level(Softcut self, int voice, float amp);
void softcut_set_pre_level(Softcut self, int voice, float amp);

void softcut_set_rec_flag(Softcut self, int voice, bool val);
void softcut_set_rec_once_flag(Softcut self, int voice, bool val);
void softcut_set_play_flag(Softcut self, int voice, bool val);

void softcut_cut_to_pos(Softcut self, int voice, float sec);

void softcut_set_pre_filter_fc(Softcut self, int voice, float x);
void softcut_set_pre_filter_rq(Softcut self, int voice, float x);
void softcut_set_pre_filter_lp(Softcut self, int voice, float x);
void softcut_set_pre_filter_hp(Softcut self, int voice, float x);
void softcut_set_pre_filter_bp(Softcut self, int voice, float x);
void softcut_set_pre_filter_br(Softcut self, int voice, float x);
void softcut_set_pre_filter_dry(Softcut self, int voice, float x);
void softcut_set_pre_filter_fc_mod(Softcut self, int voice, float x);

void softcut_set_post_filter_fc(Softcut self, int voice, float x);
void softcut_set_post_filter_rq(Softcut self, int voice, float x);
void softcut_set_post_filter_lp(Softcut self, int voice, float x);
void softcut_set_post_filter_hp(Softcut self, int voice, float x);
void softcut_set_post_filter_bp(Softcut self, int voice, float x);
void softcut_set_post_filter_br(Softcut self, int voice, float x);
void softcut_set_post_filter_dry(Softcut self, int voice, float x);

void softcut_set_rec_offset(Softcut self, int i, float d);
// void softcut_set_level_slew_time(Softcut self, int i, float d);
void softcut_set_rec_pre_slew_time(Softcut self, int i, float d);
void softcut_set_rate_slew_time(Softcut self, int i, float d);

phase_t softcut_get_quant_phase(Softcut self, int i);
void softcut_set_phase_quant(Softcut self, int i, phase_t q);
void softcut_set_phase_offset(Softcut self, int i, float sec);

bool softcut_get_rec_flag(Softcut self, int i);
bool softcut_get_play_flag(Softcut self, int i);

void softcut_sync_voice(Softcut self, int follow, int lead, float offset);
void softcut_set_voice_buffer(Softcut self, int id, float *buf, size_t bufFrames);

// can be called from non-audio threads
float softcut_get_saved_position(Softcut self, int i);

void softcut_stop_voice(Softcut self, int i);

#ifdef __cplusplus
}
#endif
     
#endif // SOFTCUT_C_SOFTCUT_H
