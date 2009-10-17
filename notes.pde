// Polyphonic sine generation 
// 
// Richard Sewell,  richard@jarkman.co.uk
//
// based on the Auduino grain-synthesis code and 
// the Arduino Theremin/Synth Code developed by Max Pierson , blog.wingedvictorydesign.com
// http://blog.wingedvictorydesign.com/2009/06/20/arduino-thereminsynth-final-walkthrough/3/
// and some footling about on a rainy afternoon

// This file does the work to manage an array of simultaneous notes
// You will want to add it to a sketch with some other file that implements setup() and loop() and 
// does the work of deciding what notes to play when.

// That file has three responsibilities:
// you should #include "note.h"
// setupNotes() must be called from your setup() function
// startNote() adds a note to the array and starts it playing

#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>

// respect the sweep parameter to start_note

//#include "notes.h"

unsigned char noteVolume[CHANNELS];             // overall note volume

unsigned char noteWorking[CHANNELS]; // Flag, non-zero to indicate note is active; zeroed when envelope decays to 0 
long int noteStartTime[CHANNELS];    // Note start timestamp, in milliseconds

unsigned char noteNumber[CHANNELS];  // Midi note number, 0..127
unsigned char noteVoice[CHANNELS];   // Which voice to use for this note, 0..MAXVOICES

uint16_t notePhase[CHANNELS];        // Phase in range 0..65535
int16_t notePhaseDelta[CHANNELS];    // Add to phase every 32 microseconds (at 31.25kHz PWM frequency)


#ifdef DO_SWEEP
// Sweeping notes (variable frequency)
int16_t noteSweepTicksTotal[CHANNELS];   // number of 32k ticks per increment of phaseDelta
int16_t noteSweepTicker[CHANNELS];
int16_t noteSweepTarget[CHANNELS]; // target value of phaseDelta for the sweep
#endif

// Notes with variable amplitude (envelope shaping)
unsigned int envelopePhase[CHANNELS];      // Envelope phase accumulator for this note 
unsigned int envelopePhaseDelta[CHANNELS]; // Add to amplitude every 8 milliseconds (at 31.25kHz PWM frequency)
unsigned char noteEnv[CHANNELS];        // Note envelope 0..255
unsigned short int noteEnvOffset[CHANNELS]; // Offset from start of envelope ROM array


#ifdef DO_VIBRATO
int16_t vibratoOffset[CHANNELS];
int16_t vibratoCounter = 0;
#endif


#if defined(__AVR_ATmega8__)
//
// On old ATmega8 boards.
//    Output is on pin 11
//
#define LED_PIN       13
#define LED_PORT      PORTB
#define LED_BIT       5

#define PWM_PIN       11
#define PWM_VALUE     OCR2
#define PWM_INTERRUPT TIMER2_OVF_vect
#elif defined(__AVR_ATmega1280__)
//
// On the Arduino Mega
//    Output is on pin 3
//
#define LED_PIN       13
#define LED_PORT      PORTB
#define LED_BIT       7

#define PWM_PIN       3
#define PWM_VALUE     OCR3C
#define PWM_INTERRUPT TIMER3_OVF_vect
#else
//
// For modern ATmega168 and ATmega328 boards
//    Output is on pin 3
//
#define LED_PIN       13
#define LED_PORT      PORTB
#define LED_BIT       5

#define PWM_PIN       3
#define PWM_VALUE     OCR2B
#define PWM_INTERRUPT TIMER2_OVF_vect
#endif


// Wave generation look-up table
#define SAMPLESIZE 32
char wave[MAXVOICES][32] = {
  {   0,  25,  49,  71,  90, 106, 117, 125,  // sine
    127, 125, 117, 106,  90,  71,  49,  25,
      0, -24, -48, -70, -89,-105,-116,-124,
   -126,-124,-116,-105, -89, -70, -48, -24},
  {-127,-127,-127,-127,-127,-127,-127,-127,  // square
   -127,-127,-127,-127,-127,-127,-127,-127,
    127, 127, 127, 127, 127, 127, 127, 127,
    127, 127, 127, 127, 127, 127, 127, 127},
  {-127,-112, -96, -80, -64, -48, -32, -16,  // triangle
      0,  16,  32,  48,  64,  80,  96, 112,
    127, 112,  96,  80,  64,  48,  32,  16,
      0, -16, -32, -64, -80, -96,-112,-127},
  {-127,-119,-111,-103, -95, -87, -79, -71,  // sawtooth
    -63, -55, -47, -39, -31, -23, -15,  -7,
      1,   9,  17,  25,  33,  41,  49,  57,
     65,  73,  81,  89,  97, 105, 113, 121},
  {  76,  88,  83,  77,  71,  65,  60,  54,  // brass
     48,  42,  36,  31,  25,  19,  14,   8,
      2,  -4,  -9, -15, -21, -27, -33, -38,
    -44, -49, -55, -61, -66, -72, -78, -84},
  {  14,  48,  69,  74,  75,  83,  85,  65,  // vibra
     24, -18, -63, -94, -96, -86, -77, -66,
    -43,  -7,  31,  79, 112, 113,  91,  65,
     37,   8, -21, -48, -84,-113,-114, -86},
  {  14,  48,  -92,  74,  -23,  83,  6,  65,  // noise
     -18, -18, 55, -94, 4, -86, 16, -66,
    -43,  22,  31,  107, 112, 5,  91,  24,
     37,   -80, -21, 19, -84,12,-114, -5}
};

// Envelope look-up table in program memory (Flash ROM)
PROGMEM prog_uchar env[MAXENVELOPES * 256] = {
/* Envelope 0   ENVELOPE_LINEAR*/
  255, 254, 253, 252, 251, 250, 249, 248,
  247, 246, 245, 244, 243, 242, 241, 240,
  239, 238, 237, 236, 235, 234, 233, 232,
  231, 230, 229, 228, 227, 226, 225, 224,
  223, 222, 221, 220, 219, 218, 217, 216,
  215, 214, 213, 212, 211, 210, 209, 208,
  207, 206, 205, 204, 203, 202, 201, 200,
  199, 198, 197, 196, 195, 194, 193, 192,
  191, 190, 189, 188, 187, 186, 185, 184,
  183, 182, 181, 180, 179, 178, 177, 176,
  175, 174, 173, 172, 171, 170, 169, 168,
  167, 166, 165, 164, 163, 162, 161, 160,
  159, 158, 157, 156, 155, 154, 153, 152,
  151, 150, 149, 148, 147, 146, 145, 144,
  143, 142, 141, 140, 139, 138, 137, 136,
  135, 134, 133, 132, 131, 130, 129, 128,
  127, 126, 125, 124, 123, 122, 121, 120,
  119, 118, 117, 116, 115, 114, 113, 112,
  111, 110, 109, 108, 107, 106, 105, 104,
  103, 102, 101, 100,  99,  98,  97,  96,
   95,  94,  93,  92,  91,  90,  89,  88,
   87,  86,  85,  84,  83,  82,  81,  80,
   79,  78,  77,  76,  75,  74,  73,  72,
   71,  70,  69,  68,  67,  66,  65,  64,
   63,  62,  61,  60,  59,  58,  57,  56,
   55,  54,  53,  52,  51,  50,  49,  48,
   47,  46,  45,  44,  43,  42,  41,  40,
   39,  38,  37,  36,  35,  34,  33,  32,
   31,  30,  29,  28,  27,  26,  25,  24,
   23,  22,  21,  20,  19,  18,  17,  16,
   15,  14,  13,  12,  11,  10,   9,   8,
    7,   6,   5,   4,   3,   2,   1,   0,
/* Envelope 1 ENVELOPE_EXP */
  255, 249, 244, 238, 233, 228, 223, 218,
  214, 209, 205, 200, 196, 192, 188, 183,
  180, 176, 172, 168, 164, 161, 157, 154,
  151, 147, 144, 141, 138, 135, 132, 129,
  127, 124, 121, 118, 116, 113, 111, 108,
  106, 104, 102,  99,  97,  95,  93,  91,
   89,  87,  85,  83,  81,  80,  78,  76,
   75,  73,  71,  70,  68,  67,  65,  64,
   63,  61,  60,  58,  57,  56,  55,  53,
   52,  51,  50,  49,  48,  47,  46,  45,
   44,  43,  42,  41,  40,  39,  38,  37,
   37,  36,  35,  34,  33,  33,  32,  31,
   31,  30,  29,  28,  28,  27,  27,  26,
   25,  25,  24,  24,  23,  23,  22,  22,
   21,  21,  20,  20,  19,  19,  18,  18,
   18,  17,  17,  16,  16,  16,  15,  15,
   15,  14,  14,  13,  13,  13,  13,  12,
   12,  12,  11,  11,  11,  11,  10,  10,
   10,  10,   9,   9,   9,   9,   8,   8,
    8,   8,   8,   7,   7,   7,   7,   7,
    7,   6,   6,   6,   6,   6,   6,   5,
    5,   5,   5,   5,   5,   5,   4,   4,
    4,   4,   4,   4,   4,   4,   3,   3,
    3,   3,   3,   3,   3,   3,   3,   3,
    3,   2,   2,   2,   2,   2,   2,   2,
    2,   2,   2,   2,   2,   2,   1,   1,
    1,   1,   1,   1,   1,   1,   1,   1,
    1,   1,   1,   1,   1,   1,   1,   1,
    1,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,
/* Envelope 2 ENVELOPE_GATE */
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  254, 255, 255, 255, 255, 255, 255, 255, // byte changed to 254 to work around Arduino bug
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255,   0,
/* Envelope 3 ENVELOPE_ADSR  */
  255, 249, 244, 238, 233, 228, 223, 218,
  214, 209, 205, 200, 196, 192, 188, 183,
  180, 176, 172, 168, 164, 161, 157, 154,
  151, 147, 144, 141, 138, 135, 132, 129,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 127, 127, 127, 127, 127, 127, 127,
  127, 117, 108, 100,  93,  86,  80,  74,
   68,  63,  58,  54,  50,  46,  43,  40,
   37,  34,  31,  29,  27,  25,  23,  21,
   19,  18,  16,  15,  14,  13,  12,  11,
   10,   9,   8,   8,   7,   6,   6,   5,
    5,   4,   4,   3,   3,   3,   2,   2,
    2,   2,   1,   1,   1,   1,   1,   0,
    0,   0,   0,   0,   0,   0,   0,   0,
/* Envelope 4 ENVELOPE_SUSTAIN  */
    0,  40,  74, 103, 128, 148, 165, 179,
  192, 202, 210, 217, 224, 229, 233, 236,
  240, 242, 244, 246, 248, 249, 250, 251,
  252, 252, 253, 253, 254, 254, 254, 254,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255,
  255, 233, 214, 196, 180, 164, 151, 138,
  127, 116, 106,  97,  89,  81,  75,  68,
   63,  57,  52,  48,  44,  40,  37,  33,
   31,  28,  25,  23,  21,  19,  18,  16,
   15,  13,  12,  11,  10,   9,   8,   7,
    7,   6,   5,   5,   4,   4,   3,   3,
    3,   2,   2,   2,   1,   1,   1,   1,
    1,   0,   0,   0,   0,   0,   0,   0,
/* Envelope 5 ENVELOPE_TREMOLO  */
  255, 249, 244, 238, 233, 228, 223, 218,
  214, 209, 205, 200, 196, 192, 188, 183,
  180, 176, 172, 168, 164, 161, 157, 154,
  151, 147, 144, 141, 138, 135, 132, 129,
  127, 139, 151, 162, 172, 180, 186, 189,
  191, 189, 186, 180, 172, 162, 151, 139,
  126, 114, 102,  91,  81,  73,  67,  64,
   63,  64,  67,  73,  81,  91, 102, 114,
  127, 139, 151, 162, 172, 180, 186, 189,
  191, 189, 186, 180, 172, 162, 151, 139,
  126, 114, 102,  91,  81,  73,  67,  64,
   63,  64,  67,  73,  81,  91, 102, 114,
  127, 139, 151, 162, 172, 180, 186, 189,
  191, 189, 186, 180, 172, 162, 151, 139,
  126, 114, 102,  91,  81,  73,  67,  64,
   63,  64,  67,  73,  81,  91, 102, 114,
  127, 139, 151, 162, 172, 180, 186, 189,
  191, 189, 186, 180, 172, 162, 151, 139,
  126, 114, 102,  91,  81,  73,  67,  64,
   63,  64,  67,  73,  81,  91, 102, 114,
  127, 139, 151, 162, 172, 180, 186, 189,
  191, 189, 186, 180, 172, 162, 151, 139,
  126, 114, 102,  91,  81,  73,  67,  64,
   63,  64,  67,  73,  81,  91, 102, 114,
  127, 117, 108, 100,  93,  86,  80,  74,
   68,  63,  58,  54,  50,  46,  43,  40,
   37,  34,  31,  29,  27,  25,  23,  21,
   19,  18,  16,  15,  14,  13,  12,  11,
   10,   9,   8,   8,   7,   6,   6,   5,
    5,   4,   4,   3,   3,   3,   2,   2,
    2,   2,   1,   1,   1,   1,   1,   0,
    0,   0,   0,   0,   0,   0,   0,   0
};




// Stepped chromatic mapping
// n = (65536 * freq) / 31250
// Place this table in program memory (Flash ROM) to save RAM
PROGMEM prog_uint16_t midiTable[128] = {
/*  C,   C#,    D,   D#,    E,    F,   F#,    G,   G#,    A,   A#,    B */
   17,   18,   19,   20,   21,   22,   24,   25,   27,   28,   30,   32,
   34,   36,   38,   40,   43,   45,   48,   51,   54,   57,   61,   64,
   68,   72,   76,   81,   86,   91,   96,  102,  108,  115,  122,  129,
  137,  145,  153,  163,  172,  183,  193,  205,  217,  230,  244,  258,
  274,  290,  307,  326,  345,  366,  387,  411,  435,  461,  488,  517,
  548,  581,  615,  652,  691,  732,  775,  822,  870,  922,  977, 1035,
 1097, 1162, 1231, 1304, 1382, 1464, 1551, 1644, 1741, 1845, 1955, 2071,
 2194, 2325, 2463, 2609, 2765, 2929, 3103, 3288, 3483, 3690, 3910, 4142,
 4389, 4650, 4926, 5219, 5530, 5859, 6207, 6576, 6967, 7381, 7820, 8285,
 8778, 9300, 9853,10439,11060,11718,12414,13153,13935,14763,15641,16571,
17557,18601,19707,20879,22120,23436,24829,26306
};

uint16_t maxMidi = (sizeof (midiTable) / sizeof (midiTable[0])) - 1;

static uint16_t mapMidi (uint16_t input)
{  
  if (input > maxMidi)
    input = maxMidi;

  return pgm_read_word_near (midiTable + input);
}


/* audioOn --- set up the PWM hardware to 31.25kHz */

static void audioOn (void)
{
#if defined(__AVR_ATmega8__)
  // ATmega8 has different registers
  TCCR2 = _BV(WGM20) | _BV(COM21) | _BV(CS20);
  TIMSK = _BV(TOIE2);
#elif defined(__AVR_ATmega1280__)
  TCCR3A = _BV(COM3C1) | _BV(WGM30);
  TCCR3B = _BV(CS30);
  TIMSK3 = _BV(TOIE3);
#else
  // Set up PWM to 31.25kHz, phase accurate
  TCCR2A = _BV(COM2B1) | _BV(WGM20);
  TCCR2B = _BV(CS20);
  TIMSK2 = _BV(TOIE2);
#endif
}

void setupNotes (void) // call from setup()
{
  //Serial.begin (9600); // for debugging
  
  pinMode (PWM_PIN,OUTPUT);
  //pinMode (LED_PIN,OUTPUT);
  
  audioOn (); // turn on appropriate interrupts
  clearNotes (); // set audio amplitude to zero
}


/* clearNotes --- initialise the note data arrays */

static void clearNotes (void)
{
  int i;
  
  for (i = 0; i < CHANNELS; i++) {
    noteWorking[i] = 0;
  
    noteStartTime[i] = 0;
  
    noteNumber[i] = 0;  // midi note number
    noteVoice[i] = 0;   // default to voice 0
    noteVolume[i] = 0;
  
    notePhase[i] = 0;  // phase in range 0->64k
    notePhaseDelta[i] = 0; // add to phase every 32 microseconds (at 31.25kHz PWM frequency)
  
#ifdef DO_SWEEP
    // sweeping notes
    noteSweepTicksTotal[i] = 0;   // number of 32k ticks per increment of phaseDelta
    noteSweepTicker[i] = 0;
    noteSweepTarget[i] = 0; // target value of phaseDelta for the sweep
#endif

    // volume-changing notes
    envelopePhase[i] = 0;  // volume of this note 
    envelopePhaseDelta[i] = 0; // subtract from volume every 32 microseconds (at 31.25kHz PWM frequency)
    noteEnvOffset[i] = 0;
    noteEnv[i] = 0;
  

  
#ifdef DO_VIBRATO
    vibratoOffset[i] = 0;
#endif
  }
}


/* startNote --- start a note playing with a given MIDI note number, voice and envelope */

void startNote (int channel, int midiNoteNumber, unsigned char volume, int voice, int envelopeDelta, int envelope, int sweepMillisecs, int vibratoPercent)
{
  if ((channel >= CHANNELS) || (voice >= MAXVOICES))
    return;
    
   noteWorking[channel] = 1;
   noteStartTime[channel] = millis ();
   
//LED_PORT ^= 1 << LED_BIT; // led toggles for each channel
  
  noteNumber[channel] = midiNoteNumber;
  noteVoice[channel] = voice;
  noteVolume[channel] = volume;
  
  notePhase[channel] = 0;
  
  int16_t basePhaseDelta = mapMidi (midiNoteNumber); // a notePhaseDelta of 2048 gives you 1kHz here

#ifdef DO_SWEEP
  if (sweepMillisecs == 0) { 
    notePhaseDelta[channel] = basePhaseDelta;
    noteSweepTicksTotal[channel] = 0;
    noteSweepTarget[channel] = notePhaseDelta[channel];  
  }
  else {
    noteSweepTarget[ channel ] = basePhaseDelta;
   
   // number of 32k ticks per increment of phaseDelta
    if( noteSweepTarget[channel] == notePhaseDelta[channel])
      noteSweepTicksTotal[channel] = 0;
    else  
      noteSweepTicksTotal[channel] = (sweepMillisecs << 5) / (noteSweepTarget[channel] - notePhaseDelta[channel]);
    //noteSweepDelta[channel] = (noteSweepTarget[channel] - notePhaseDelta[channel]) / (sweepMillisecs >> 3); // sweepMillisecs * 32 / 256
    //if( noteTicksTotal[channel] == 0 ) // can't go slow enough - channel will never finish
    //  envelopeDelta = 100; // make the
      
    noteSweepTicker[channel] = 0;
  }
#else
  sweepMillisecs = 0;
  notePhaseDelta[channel] = basePhaseDelta;
#endif
      
  if (envelopeDelta == 0) // forbid endless notes for the convenience of my random-channel generation scheme
    envelopeDelta = 1; 

#ifdef DO_VIBRATO
  vibratoOffset[channel] = basePhaseDelta >> 3; // we will add this to phaseDelta for half the vibrato cycle and subtract it for the other half
  vibratoOffset[channel] = (vibratoPercent * vibratoOffset[channel]) / 100; // 25 percent is a rational value
  if (vibratoOffset[channel] < 1)
    vibratoOffset[channel] = 1;
#endif

  noteEnvOffset[channel] = envelope * 256;  
  noteEnv[channel] = 255;
  envelopePhase[channel] = 0;  // Initialise envelope phase accumulator
  envelopePhaseDelta[channel] = envelopeDelta; // Add to volume every 8 msec
                                       // a value of 256 gives a 1-second envelope
  


}


/* quietestNote --- not used, but needs updating */

int quietestNote (void)
{
  int minNote = -1;
  int16_t minVolume = 0;
  int channel;
  
  for (channel = 0; channel < CHANNELS; channel++) {
    if (noteFinished (channel))
      return (channel);
    
    if (minVolume > envelopePhase[channel]) {
        minVolume = envelopePhase[channel];  
        minNote = channel;
    }
  }

  return (minNote);  
}


/* noteFinished --- not used, but needs updating */

int noteFinished (int channel)
{
  return envelopePhase[channel] == 65535U ||
          (! noteWorking[channel]) || 
          millis() - noteStartTime[channel] > 500 ; // so notes with no volume or pitch sweep still finish
  //return envelopePhase[channel] <= 0;
}


/* startNoteStep --- not used, but needs updating */
/*
void startNoteStep (int channel, int noteDelta, int minNoteNumber, int maxNoteNumber , int envelopeDelta)
{
  int n = noteNumber[channel] + noteDelta;
  
  if (n < minNoteNumber)
    n = maxNoteNumber;
    
  if (n > maxNoteNumber)
     n = minNoteNumber;
    
   startNote (channel, n, 0, envelopeDelta, 0, 200, 25); 
}
*/

long nextProgressEnvelopeTime = 0;

void progressEnvelopes() // must be called from loop() 
{
  int e;
  long now = millis();
  
  if( now < nextProgressEnvelopeTime )
    return;
    
   nextProgressEnvelopeTime = now + 8L; // do this every 8 millisecs
    
  for (int channel = 0; channel < CHANNELS; channel++)
  {
      // Process volume every 256 times round the loop so we can have decent note lengths.
      // We go through here every 32*256 microsecs, 8 millisecs, 128 times / sec.
      // Apply envelope shaping to the note fundamental volume.
      if (envelopePhase[channel] < (65535U - envelopePhaseDelta[channel])) 
      {
        envelopePhase[channel] += envelopePhaseDelta[channel];
        e = envelopePhase[channel] >> 8;
        e += noteEnvOffset[channel];
        noteEnv[channel] = pgm_read_byte_near (env + e);
      }
      else 
      {
        noteWorking[channel] = 0;
        noteEnv[channel] = 0;
        envelopePhase[channel] = 65535U; // Note is done
      }
    }   
  }
      
SIGNAL(PWM_INTERRUPT)  // every 32 microsecs, i.e. 31.25kHz
{
  int16_t fundamentalValue;

  int16_t output = 0;
  char channel;
  int e;
  

 
  for (channel = 0; channel < CHANNELS; channel++) {
    
    notePhase[channel] += notePhaseDelta[channel]; // we just let it wrap when it overflows
  
#ifdef DO_VIBRATO
    if (vibratoCounter > 0)
      notePhase[channel] += vibratoOffset[channel];
    else
      notePhase[channel] -= vibratoOffset[channel];
#endif
    
    fundamentalValue = wave[noteVoice[channel]][ notePhase[channel] >> 11 ];  // gets from 16-bit down to our 5-bit wave table
                                            // value is in range -127..127
    fundamentalValue *= noteEnv[channel];   // Apply envelope shaping
    
    //noteVolume[channel] = 1;
    fundamentalValue *= (int16_t) noteVolume[channel];
    
#ifdef DO_SWEEP
    if( noteSweepTicksTotal[channel] != 0 )
    {
      noteSweepTicker[channel] ++;
      if( noteSweepTicker[channel] >= abs( noteSweepTicksTotal[channel] ))
      {
        noteSweepTicker[channel] = 0;
        if( noteSweepTicksTotal[channel] > 0 )
          notePhaseDelta[channel] ++;
        else
          notePhaseDelta[channel] --;
          
         
        if( (int)notePhaseDelta[channel] == (int)noteSweepTarget[channel])
        {
          notePhaseDelta[channel] = noteSweepTarget[channel];
          noteSweepTicksTotal[channel] = 0; //arrived, so stop
          noteWorking[channel] = 0;
        }
      }
    }        
#endif
    
  
    

    output += (fundamentalValue >> 3); // Sum the notes to get the total output
    
  } // end loop over CHANNELS
 
#ifdef DO_VIBRATO
  if (volumeCounter == 0) { 
    vibratoCounter++;
    if (vibratoCounter > 8)
      vibratoCounter = -8;
  }
#endif

  // Scale output to the available range, clipping if necessary
  output >>= 8;
  output += 127; // get from 0-based to 127-based
  if (output > 255)
    output = 255;

  // Output to PWM (this is faster than using analogWrite)  
  PWM_VALUE = output;
}

