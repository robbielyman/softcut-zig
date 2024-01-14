#include "include/softcut_c.h"
#include <softcut/Softcut.h>

typedef softcut::Softcut<SOFTCUT_C_NUMVOICES> SC;

Softcut softcut_init() {
  Softcut wrp = new softcut_t;

  SC *sc = new SC();
  wrp->ptr = (void *)sc;

  return wrp;
}

void softcut_destroy(Softcut self) {
  SC *sc = (SC *)self->ptr;
  delete sc;
  delete self;
}

void softcut_reset(Softcut self) {
  SC *sc = (SC *)self->ptr;
  sc->reset();
}

void softcut_process_block(Softcut self, int v, const float *in, float *out,
                           int numFrames) {
  SC *sc = (SC *)self->ptr;
  sc->processBlock(v, in, out, numFrames);
}

void softcut_set_samplerate(Softcut self, unsigned int hz) {
  SC *sc = (SC *)self->ptr;
  sc->setSampleRate(hz);
}

void softcut_set_rate(Softcut self, int voice, float rate) {
  SC *sc = (SC *)self->ptr;
  sc->setRate(voice, rate);
}

void softcut_set_loop_start(Softcut self, int voice, float sec) {
  SC *sc = (SC *)self->ptr;
  sc->setLoopStart(voice, sec);
}

void softcut_set_loop_end(Softcut self, int voice, float sec) {
  SC *sc = (SC *)self->ptr;
  sc->setLoopEnd(voice, sec);
}

void softcut_set_loop_flag(Softcut self, int voice, bool flag) {
  SC *sc = (SC *)self->ptr;
  sc->setLoopFlag(voice, flag);
}

void softcut_set_fade_time(Softcut self, int voice, float sec) {
  SC *sc = (SC *)self->ptr;
  sc->setFadeTime(voice, sec);
}

void softcut_set_rec_level(Softcut self, int voice, float amp) {
  SC *sc = (SC *)self->ptr;
  sc->setRecLevel(voice, amp);
}

void softcut_set_pre_level(Softcut self, int voice, float amp) {
  SC *sc = (SC *)self->ptr;
  sc->setPreLevel(voice, amp);
}

void softcut_set_rec_flag(Softcut self, int voice, bool val) {
  SC *sc = (SC *)self->ptr;
  sc->setRecFlag(voice, val);
}

void softcut_set_rec_once_flag(Softcut self, int voice, bool val) {
  SC *sc = (SC *)self->ptr;
  sc->setRecOnceFlag(voice, val);
}

void softcut_set_play_flag(Softcut self, int voice, bool val) {
  SC *sc = (SC *)self->ptr;
  sc->setPlayFlag(voice, val);
}

void softcut_cut_to_pos(Softcut self, int voice, float sec) {
  SC *sc = (SC *)self->ptr;
  sc->cutToPos(voice, sec);
}

void softcut_set_pre_filter_fc(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterFc(voice, x);
}

void softcut_set_pre_filter_rq(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterRq(voice, x);
}

void softcut_set_pre_filter_Lp(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterLp(voice, x);
}

void softcut_set_pre_filter_Hp(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterHp(voice, x);
}

void softcut_set_pre_filter_bp(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterBp(voice, x);
}

void softcut_set_pre_filter_br(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterBr(voice, x);
}

void softcut_set_pre_filter_dry(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterDry(voice, x);
}

void softcut_set_pre_filter_fc_mod(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterFcMod(voice, x);
}
void softcut_set_post_filter_fc(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPostFilterFc(voice, x);
}

void softcut_set_post_filter_rq(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPostFilterRq(voice, x);
}

void softcut_set_post_filter_Lp(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPreFilterLp(voice, x);
}

void softcut_set_post_filter_Hp(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPostFilterHp(voice, x);
}

void softcut_set_post_filter_bp(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPostFilterBp(voice, x);
}

void softcut_set_post_filter_br(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPostFilterBr(voice, x);
}

void softcut_set_post_filter_dry(Softcut self, int voice, float x) {
  SC *sc = (SC *)self->ptr;
  sc->setPostFilterDry(voice, x);
}

void softcut_set_rec_offset(Softcut self, int i, float d) {
  SC *sc = (SC *)self->ptr;
  sc->setRecOffset(i, d);
}

// void softcut_set_level_slew_time(Softcut self, int i, float d) {
// SC *sc = (SC *)self->ptr;
// sc->setLevelSlewTime(i, d);
// }

void softcut_set_rec_pre_slew_time(Softcut self, int i, float d) {
  SC *sc = (SC *)self->ptr;
  sc->setRecPreSlewTime(i, d);
}

void softcut_set_rate_slew_time(Softcut self, int i, float d) {
  SC *sc = (SC *)self->ptr;
  sc->setRateSlewTime(i, d);
}

phase_t softcut_get_quant_phase(Softcut self, int i) {
  SC *sc = (SC *)self->ptr;
  return sc->getQuantPhase(i);
}

void softcut_set_phase_quant(Softcut self, int i, phase_t q) {
  SC *sc = (SC *)self->ptr;
  sc->setPhaseQuant(i, q);
}

void softcut_set_phase_offset(Softcut self, int i, float sec) {
  SC *sc = (SC *)self->ptr;
  sc->setPhaseOffset(i, sec);
}

bool softcut_get_rec_flag(Softcut self, int i) {
  SC *sc = (SC *)self->ptr;
  return sc->getRecFlag(i);
}

bool softcut_get_play_flag(Softcut self, int i) {
  SC *sc = (SC *)self->ptr;
  return sc->getPlayFlag(i);
}

void softcut_sync_voice(Softcut self, int follow, int lead, float offset) {
  SC *sc = (SC *)self->ptr;
  sc->syncVoice(follow, lead, offset);
}

void softcut_set_voice_buffer(Softcut self, int id, float *buf,
                              size_t bufFrames) {
  SC *sc = (SC *)self->ptr;
  sc->setVoiceBuffer(id, buf, bufFrames);
}

float softcut_get_saved_position(Softcut self, int i) {
  SC *sc = (SC *)self->ptr;
  return sc->getSavedPosition(i);
}

void softcut_stop_voice(Softcut self, int i) {
  SC *sc = (SC *)self->ptr;
  sc->stopVoice(i);
}
