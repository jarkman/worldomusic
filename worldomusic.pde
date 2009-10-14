
/* world'O'music - generate tunes from GPS location */

#include <avr/io.h>
#include "notes.h"
#include "tune.h"
#include "NMEA.h"

//#define DO_LOGGING // NB - logging and GPS usage are incompatible! Do not leave Serial.out lines in place when DO_LOGGING is off!
#define SIMULATE_GPS








 unsigned long bitList( unsigned long whiskers, char*bits );
 unsigned long bitRange( unsigned long whiskers, int lowBit, int highBit );
 unsigned long mixBits( unsigned long left, unsigned long right );
 
int countBits( unsigned long left );
 
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
  
  decode_gps();  //Reads and average the sensors when is doing nothing...

  if( progressTune()) // only make a new tune when the old one finishes
   buildTuneFromPosition();
}

void presetVoices()
 {
  // down to 2 channels to make the GPS work
  

  tuneSetVoice (0, VOICE_VIBRA);
  tuneSetVoice (1, VOICE_SINE);
  //tuneSetVoice (2, VOICE_VIBRA);
  
  //tuneSetEnvelopeDelta (0, 1200);
  //tuneSetEnvelopeDelta (1, 600);
  ////tuneSetEnvelopeDelta (2, 300);
  
  tuneSetVibratoPercent (0, 15);
  
  //tuneSetEnvelope (0, ENVELOPE_SUSTAIN);
  //tuneSetEnvelope (1, ENVELOPE_EXP);
  //tuneSetEnvelope (2, ENVELOPE_TREMOLO); 
  tuneSetEnvelope (0, ENVELOPE_EXP);
  tuneSetEnvelope (1, ENVELOPE_ADSR);
  //tuneSetEnvelope (2, ENVELOPE_TREMOLO);
  
 }
 
#define NUM_ACTIVES 5
#define NUM_SCALES 2

unsigned short int scaleA[] = { 55,57,59,60,62,64,65,0 };

unsigned short int scaleB [] = { 45,47,49,50,52,54,55,0 };

unsigned short int *scales[] = { scaleA, scaleB, NULL };


unsigned short int activeNotes[CHANNELS][ NUM_ACTIVES ];
int numActives[CHANNELS];


void pickActivesFromPosition() // pick a set of active notes to play based on position 
{
  int scale = pickScaleFromPosition();
  
  for( int channel = 0; channel < CHANNELS; channel ++ )
  {
    int a  = 0;
    for( int i = 0; scales[scale][i] != 0 && a < NUM_ACTIVES; i ++ )
    {
      unsigned long noteMask;
      if( i == 0 )
        noteMask = latWhiskers;
       else
       noteMask = lonWhiskers;
       
      if( bitIsSet( noteMask, i ))
      {
        activeNotes[channel][a] = scales[scale][i];
        a++;
       }
    
    }
    
    numActives[channel] = a;
    
    for( ; a < NUM_ACTIVES; a ++ )
      activeNotes[channel][a] = 0;
  }
}

int pickScaleFromPosition()
{
   int s = (countBits( bitList( latWhiskers, "0000 0000 0000 0000 0000 0011 1111" )) % NUM_SCALES );
   return s;
}


 void buildTuneFromPosition()
 {
   static unsigned long lastLat = -1;
   static unsigned long lastLon = -1;
   static int lastGpsStatus = -1;
   
   if( lonWhiskers == lastLon && latWhiskers == lastLat && lastGpsStatus == gpsStatus ) //same position 
     return;
    
    lastLon = lonWhiskers;
    lastLat = latWhiskers;
    lastGpsStatus = gpsStatus;
    
    #ifdef DO_LOGGING
     Serial.print ("buildTuneFromPosition - lat, lon: ");
      Serial.print (latWhiskers, DEC); 
      Serial.print (lonWhiskers, DEC); 
      Serial.print ("\n");
    #endif
    
    if( gpsStatus != GPS_STATUS_FIX  )
      buildNoGpsTune();
    else
      buildTune();
      
    //buildTestTune();
 }
 

 void buildTune()
 {
   
   pickActivesFromPosition();
   
   
   // the tune is built from latWhiskers and lonWhiskers
   // Each of those has 28 interesting bits, of which the low bits are obviously the most interesting
   
   int beatMillisecs = 200 + (5 * bitList( latWhiskers, "0000 0000 0000 0000 0000 0011 1111" )); 

   int numBeats; // = 3 + bitList( lonWhiskers, "0000 0000 0000 0000 0000 0001 1111" ); // 0 to 32
   
   int barLength = 4 + countBits( bitList( lonWhiskers, "0000 0000 0000 0000 0000 0000 0110" )); 
   
   numBeats = 3 * barLength;
   
   //unsigned long beatMask = (bitList( lonWhiskers, "0000 0000 0000 1111 1111 1111 1111" ) << 16)
   //                          | (bitList( latWhiskers, "0000 0000 0000 1111 1111 1111 1111" ));
   
   unsigned long beatMask = mixBits( lonWhiskers,  latWhiskers );  // alternate bits from the bottom 16 of the two coords
   unsigned long otherBeatMask = bitList(beatMask, "0101 0101 0101 0101 0101 0101 0101" ); 
 
   tuneDelete();
    
   tuneSetBeatInterval( beatMillisecs ); 
  
    int volume;
   int beat;
   for( beat = 0; beat < numBeats; beat ++ )
   {
       int beatOfBar = (beat % barLength);
       boolean firstBeat = ( beatOfBar == 0 ) ; // stress the first note of the 'bar'
       
       // drum line on channel 0
       if( firstBeat )
         doof( beat );
       else
         if( bitIsSet( beatMask, beatOfBar ))
           tish( beat );
       
       
       // melody on channel 1
       int volume;
       int delta;
       
       if( firstBeat )
       {
         volume = MAXVOLUME; // loudest
         delta = ENVELOPE_DELTA_LONG;
       }
       else
       {
         volume = 3; // quieter
         delta = ENVELOPE_DELTA_MEDIUM;
       }
        int channel = 1;
        
        int b = beatOfBar;
        if( beatOfBar >=3 )  // so all bars start the same but vary after the 3rd beat
          b = beat; 
          
        if( firstBeat || bitIsSet( otherBeatMask, b ))
           tuneAddNote( activeNotes[channel][b%numActives[channel]], volume, delta, beat,  channel);

        
       /*
       if( firstBeat )
         volume = MAXVOLUME; // loudest
       else
         volume = 3; // quieter
       
         
       int channel = 0;
       
       if( bitIsSet( beatMask, beat ) || firstBeat )
         tuneAddNote( activeNotes[channel][beat%numActives[channel]], volume, ENVELOPE_DELTA_SHORT, beat, channel );
         
        channel = 1;
         
       if( beat%2 == 0 )  
         tuneAddNote( activeNotes[channel][beat%numActives[channel]], 3, ENVELOPE_DELTA_MEDIUM, beat,  channel);
      */   

   }
 }
 
 void doof( int beat )  // assuming  VOICE_VIBRA and ENVELOPE_EXP, this makes a drum-ish doof on channel 0
 {
   tuneAddNote( 40, MAXVOLUME, ENVELOPE_DELTA_SHORT, beat,  0);
 }
 
 void tish( int beat )
 {
   tuneAddNote( 80, MAXVOLUME, ENVELOPE_DELTA_TINY, beat,  0);
 }
 
 void buildNoGpsTune()
 {
   
   tuneDelete();
   
   tuneSetBeatInterval( 1000 / (1 + gpsStatus));  // gets faster as it gets better
  
   int beat;
   for( beat = 0; beat < 3; beat ++ )
   {

      tuneAddNote( 50 - beat,  MAXVOLUME, ENVELOPE_DELTA_SHORT, beat, 1 );
      
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
        tuneAddNote( 50 + beat,  MAXVOLUME, ENVELOPE_DELTA_SHORT, beat, 0 );
      
      tuneAddNote( 60 + (3 * (beat%2)), MAXVOLUME, ENVELOPE_DELTA_SHORT, beat, 1 );
      
      if( beat%5 == 0 )
        tuneAddNote( 50 + beat%2, MAXVOLUME, ENVELOPE_DELTA_SHORT, beat, 2 );
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
 
int countBits( unsigned long left )

 {    
   int count = 0;
   unsigned long inBit = 1L;
   
   for( int i = 0; i < 32; i ++)
   {
     if( left & inBit )
       count ++;;
       
    
       inBit <<= 1;
       
   }
   
   return count;
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
   


