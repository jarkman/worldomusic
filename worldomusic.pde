
/* world'O'music - generate tunes from GPS location */

#include <avr/io.h>
#include "notes.h"
#include "tune.h"
#include "NMEA.h"

#define DO_LOGGING // NB - logging and GPS usage are incompatible! Do not leave Serial.out lines in place when DO_LOGGING is off!
#define SIMULATE_GPS

//#define SIMULATE_TRIGGERS  // turn on to test when we don't have input hardware



 unsigned long bitList( unsigned long whiskers, char*bits );
 unsigned long bitRange( unsigned long whiskers, int lowBit, int highBit );
 unsigned long mixBits( unsigned long left, unsigned long right );
 
 int bitIsSet( unsigned long in, int bitNumber );

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
  progressEnvelopes();
  
  progressTune();
  
  decode_gps();  //Reads and average the sensors when is doing nothing...

   buildTuneFromPosition();
}

void presetVoices()
 {
  
  tuneSetVoice (0, VOICE_SAWTOOTH);
  tuneSetVoice (1, VOICE_SINE);
  tuneSetVoice (2, VOICE_VIBRA);
  
  tuneSetEnvelopeDelta (0, 600);
  tuneSetEnvelopeDelta (1, 600);
  tuneSetEnvelopeDelta (2, 300);
  
  tuneSetVibratoPercent (0, 15);
  
  tuneSetEnvelope (0, ENVELOPE_SUSTAIN);
  tuneSetEnvelope (1, ENVELOPE_EXP);
  tuneSetEnvelope (2, ENVELOPE_TREMOLO);
  
 }
 
 void buildTuneFromPosition()
 {
   static unsigned long lastLat = 0;
   static unsigned long lastLon = 0;
   
   if( lonWhiskers == lastLon && latWhiskers == lastLat  ) //same position 
     return;
    
    lastLon = lonWhiskers;
    lastLat = latWhiskers;
    
    #ifdef DO_LOGGING
     Serial.print ("buildTuneFromPosition - lat, lon: ");
      Serial.print (latWhiskers, DEC); 
      Serial.print (lonWhiskers, DEC); 
      Serial.print ("\n");
    #endif
    
    
    buildTune();
    //buildTestTune();
 }
 

 void buildTune()
 {
   
   // the tune is built from latWhiskers and lonWhiskers
   // Each of those has 28 interesting bits, of which the low bits are obviously the most interesting
   
   int beatMillisecs = 100 + (5 * bitList( latWhiskers, "0000 0000 0000 0000 0000 0011 1111" )); 

   int numBeats = 3 + bitList( lonWhiskers, "0000 0000 0000 0000 0000 0001 1111" ); // 0 to 32
   int barLength = 2 + bitList( lonWhiskers, "0000 0000 0000 0000 0000 0001 0010" ); 
   
   //unsigned long beatMask = (bitList( lonWhiskers, "0000 0000 0000 1111 1111 1111 1111" ) << 16)
   //                          | (bitList( latWhiskers, "0000 0000 0000 1111 1111 1111 1111" ));
   
   unsigned long beatMask = mixBits( lonWhiskers,  latWhiskers );  // alternate bits from the bottom 16 of the two coords
   
 
   tuneDelete();
    
   tuneSetBeatInterval( beatMillisecs ); 
  
    int volume;
   int beat;
   for( beat = 0; beat < numBeats; beat ++ )
   {
       boolean firstBeat = ((beat % barLength) == 0 ) ; // stress the first note of the 'bar'
       if( firstBeat )
         volume = MAXVOLUME; // loudest
       else
         volume = 2; // quieter
         
       if( bitIsSet( beatMask, beat ) || firstBeat )
         tuneAddNote( 60 + (3 * (beat%2)), volume, beat, 0 );
       
   }
 }
 
 void buildTestTune()
 {
   
   tuneDelete();
    
   tuneSetBeatInterval( 700 ); 
  
   int beat;
   for( beat = 0; beat < 15; beat ++ )
   {
     
     if( beat%3 == 0 )
        tuneAddNote( 50 + beat,  MAXVOLUME, beat, 0 );
      
      tuneAddNote( 60 + (3 * (beat%2)), MAXVOLUME, beat, 1 );
      
      if( beat%5 == 0 )
        tuneAddNote( 50 + beat%2, MAXVOLUME, beat, 2 );
   }
 }
 
 int bitIsSet( unsigned long in, int bitNumber )
 {
     return 0 != (in & (1L << bitNumber ));
 }
 
 unsigned long mixBits( unsigned long left, unsigned long right )  // build a 32-bit result from the bottom 16 bits of the arguments, alternated
 {    
   unsigned long out = 0L;
   unsigned long inBit = 1L;
   unsigned long outBit = 1L;
   
   for( int i = 0; i < 16; i ++)
   {
     if( left & inBit )
       out |= outBit;
       
       outBit <<= 1;
       
       if( right & inBit )
         out |= outBit;
       
       outBit <<= 1;
       
       inBit <<= 1;
       
   }
   
   return out;
 }
 
 
 unsigned long bitList( unsigned long in, char*bits )  // collect the specified bits form 'in' and put them into the lowest bits of 'out'
 {
     unsigned long out = 0L;
     unsigned long inBit = 1L;
     unsigned long outBit = 1L;
     
     for( int c = strlen( bits ) - 1; c >= 0; c -- )
     {
       if( bits[ c ] == '0' || bits[ c ] == '1' )
       {
         if( bits[ c ] == '1')  // if the string says this is a bit we want to represent in our answer
         {
            if( ( in & inBit ) != 0L )  // if the input number has a bit in this position
               out |= outBit;            // put it in our answer
           
            outBit  = outBit << 1;
         }
         
         inBit  = inBit << 1;
       }
     }
     
     return out;
     
 }
 
 unsigned long bitRange( unsigned long whiskers, int lowBit, int highBit ) // bit numbers are inclusive, in the range 0-27
 {
     unsigned long mask = 0xFFFFFFFFL;
     mask = mask >> (31 - (highBit-lowBit));
     return mask & (whiskers >> lowBit);
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
   


