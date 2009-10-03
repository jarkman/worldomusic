
/* pisano_full_fat --- generate polyphonic melodies from Pisano numbers */

#include <avr/io.h>
#include "notes.h"
#include "tune.h"
#include "NMEA.h"

#define DO_LOGGING // NB - logging and GPS usage are incompatible!

//#define SIMULATE_TRIGGERS  // turn on to test when we don't have input hardware

/* setup --- do all the initialisation for the sketch */

void setup ()
{
  #ifdef DO_LOGGING
  Serial.begin (9600); // for debugging
  #endif
  
  setupNotes ();
  
  init_gps(); //Initializing GPS

  #ifdef DO_LOGGING
  Serial.begin (9600); // for debugging
  #endif
  
  setupTune();
  
  presetVoices();
}


void loop ()
{
  progressTune();
  
  decode_gps();  //Reads and average the sensors when is doing nothing...

   buildTuneFromPosition();
}

void presetVoices()
 {
  
  tuneSetVoice (0, VOICE_SAWTOOTH);
  tuneSetVoice (1, VOICE_SINE);
  tuneSetVoice (2, VOICE_VIBRA);
  
  tuneSetVolumeDelta (0, 600);
  tuneSetVolumeDelta (1, 600);
  tuneSetVolumeDelta (2, 300);
  
  tuneSetVibratoPercent (0, 15);
  
  tuneSetEnvelope (0, ENVELOPE_SUSTAIN);
  tuneSetEnvelope (1, ENVELOPE_EXP);
  tuneSetEnvelope (2, ENVELOPE_TREMOLO);
  
 }
 
 void buildTuneFromPosition()
 {
   static int done = 0;
   
   if( done ) //same position )
     return;
    
    done = 1; 
    
    buildTestTune();
 }
 
 void buildTestTune()
 {
   tuneDelete();
    
   tuneSetBeatInterval( 700 ); 
  
   int beat;
   for( beat = 0; beat < 15; beat ++ )
   {
     
     if( beat%3 == 0 )
        tuneAddNote( 50 + beat, beat, 0 );
      
      tuneAddNote( 60 + (3 * (beat%2)), beat, 1 );
      
      if( beat%5 == 0 )
        tuneAddNote( 50 + beat%2, beat, 2 );
   }
 }
 /*
  ///////////////////////
  // simultaneous scales!
  // c# and d# pentatonic
  ///////////////////////
  
  // sequence lengths 16,20,24
  
  // c# pentatonic scale
  // starting from c#
  // - extending 1 note extra past the octave
  // 7 notes total - produces sequence of 16 notes
  pisanoAddMIDINote (0, 61);
  pisanoAddMIDINote (0, 64);
  pisanoAddMIDINote (0, 66);
  pisanoAddMIDINote (0, 68);
  pisanoAddMIDINote (0, 71);
  pisanoAddMIDINote (0, 73);
  pisanoAddMIDINote (0, 76);
  
  // c# pentatonic scale
  // starting from f#
  // 5 notes total - produces sequence of 20 notes
  pisanoAddMIDINote (1, 66 + OCTAVE);
  pisanoAddMIDINote (1, 68 + OCTAVE);
  pisanoAddMIDINote (1, 71 + OCTAVE);
  pisanoAddMIDINote (1, 73 + OCTAVE);
  pisanoAddMIDINote (1, 76 + OCTAVE);
  
  // d# pentatonic scale
  // starting from d# and repeating at the octave
  // 6 notes total - produces a sequence of 24 notes
  pisanoAddMIDINote (2, 63 - (2 * OCTAVE));
  pisanoAddMIDINote (2, 66 - (2 * OCTAVE));
  pisanoAddMIDINote (2, 68 - (2 * OCTAVE));
  pisanoAddMIDINote (2, 71 - (2 * OCTAVE));
  pisanoAddMIDINote (2, 73 - (2 * OCTAVE));
  pisanoAddMIDINote (2, 75 - (2 * OCTAVE));    
  */
   
#ifdef SIMULATE_TRIGGERS  
void simulateTriggers()
{
  long now = millis();
  static long lastTrigger[ PISANO_GENERATORS ];
  
  for( int i = 0; i < PISANO_GENERATORS; i ++ )
  {
    if( now < lastTrigger[i] ) // must be first time
      lastTrigger[i] = now;
      
    if( now > lastTrigger[i] + 800l + (100*i)) // start at non-overlapping times
    {
      pisanoGenerateNote(i);
      lastTrigger[i] = now;
    }
  }
}
#endif

