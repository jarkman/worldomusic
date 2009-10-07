/* notes.h --- header file for polyphonic note synthesis on Arduino */

#define CHANNELS (2)        // The maximum number of notes we can play simultaneously
#define MAXVOICES (6)    // Maximum number of voices
#define MAXENVELOPES (6) // Maximum number of envelopes


#define MAXVOLUME 4


// Turning these features on reduces the maximum workable value of CHANNELS !
//#define DO_VIBRATO    // fixed vibrato on all notes
//#define DO_SWEEP      // sweep from one note to the next

#define VOICE_SINE      (0)    // Simple sine wave
#define VOICE_SQUARE    (1)    // Simple square wave
#define VOICE_TRIANGLE  (2)    // Triangle wave
#define VOICE_SAWTOOTH  (3)    // Sawtooth wave
#define VOICE_BRASS     (4)    // Phill's sampled brass
#define VOICE_VIBRA     (5)    // Phill's sampled vibraphone

#define ENVELOPE_LINEAR  (0)   // Linear decay to zero, as in original version
#define ENVELOPE_EXP     (1)   // Exponential decay, similar to a bell
#define ENVELOPE_GATE    (2)   // Simple on/off gating
#define ENVELOPE_ADSR    (3)   // Attack, decay, sustain, release
#define ENVELOPE_SUSTAIN (4)   // Short exponential attack and decay
#define ENVELOPE_TREMOLO (5)   // Like ADSR but with modulated sustain amplitude

extern uint16_t maxMidi;

extern void setupNotes (void);

extern void startNote (int channel, int midiNoteNumber, unsigned char volume, int voice, int envelopeDelta, int envelope, int sweepMillisecs, int vibratoPercent);
extern void progressEnvelopes();
