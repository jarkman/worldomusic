
/* world'O'music - generate tunes from GPS location */

#include <avr/io.h>
#include "notes.h"
#include "tune.h"
#include "NMEA.h"

//#define DO_LOGGING // NB - logging and GPS usage are incompatible! Do not leave Serial.out lines in place when DO_LOGGING is off!
//#define SIMULATE_GPS


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
  
  tuneSetVoice (0, VOICE_NOISE);
  //tuneSetVoice (1, VOICE_SINE);
  tuneSetVoice (1, VOICE_BRASS);

  
  tuneSetVibratoPercent (0, 15);
  

  tuneSetEnvelope (0, ENVELOPE_EXP);
  //tuneSetEnvelope (1, ENVELOPE_ADSR);
  tuneSetEnvelope (1, ENVELOPE_EXP);

  
 }
 
#define NUM_ACTIVES 12
#define NUM_SCALES 1

unsigned short int scaleMajor[] = { 0, 2, 4, 5, 7, 9, 11,  255 };
unsigned short int scaleMinor[] = { 0, 2, 3, 5, 7, 8, 10,  255 };
unsigned short int scaleFudgePentatonic[] = { 0, 0, 2, 4, 7, 7, 9,  255 }; // fudge the pentatonic scale to have 8 notes (repeat the root and fifth degree)
unsigned short int *scales[] = { scaleMajor, scaleMinor, scaleFudgePentatonic, NULL };

/* phill temporary - omit these more exotic scales for now
unsigned short int *scales[] = { scaleMajor, scaleMinor, scaleAlteredMinor, scalePentatonic, scalePentatonicBlues, NULL };
unsigned short int scaleAlteredMinor[] = { 0, 2, 3, 6, 7, 8, 11,  255 };
unsigned short int scalePentatonicBlues[] = { 0, 3, 5, 6, 7, 10,  255 };
unsigned short int scalePentatonic[] = { 0, 2, 4, 7, 9,  255 };
unsigned short int scaleFudgePentatonic[] = { 0, 0, 2, 4, 7, 7, 9,  255 }; // fudge the pentatonic scale to have 8 notes (repeat the root and fifth degree)
unsigned short int scaleFudgePentatonicBlues[] = { 0, 3, 5, 6, 6, 7, 10, 10,  255 }; // fudge the pentatonic scale to have 8 notes (repeat the "blue" notes)
*/

unsigned short int activeNotes[CHANNELS][ NUM_ACTIVES ];
int numActives[CHANNELS];


void pickActivesFromPosition() // pick a set of active notes to play based on position 
{
  int scale = pickScaleFromPosition();
  
  /* phill temporary -  pick the whole scale (for debugging purposes)
  for( int channel = 0; channel < CHANNELS; channel ++ )
  {
    int a  = 0; // count of allowed notes we've pulled out of the chosen scale 
    int s = 0; // index into the chosen scale we're pulling from
    
    for( int i = 0; a < NUM_ACTIVES; i ++ )
    {
      activeNotes[channel][a] = scales[scale][s] + 24; // was "+ scaleStart" - this forces a (low octave) 'C' rootNote
     
      a++;
      s++;
      
       if(  scales[scale][s] > 250 )
       {
         s = 0;
         scaleStart += 12;
       }
    }
    numActives[channel] = a;
    
    // what's this for?
    // looks like sets the end of the active notes list to zero
    for( ; a < NUM_ACTIVES; a ++ )
      activeNotes[channel][a] = 0;
  }
  */
   
  // rootNote (lowest note in the list of allowed active notes) varies, but only for large movements 
  int rootNote = 30 + bitList( lonWhiskers, "0000 0000 0000 0000 0000 0011 1000" ) % 40; 
  
  // phill temporary - this choses a list of allowed notes (actives)
  // favouring the root, fourth, and fifth degree of the scale
  // it DOES also pick other notes but the gps latWhiskers in the simulateGPS() tends
  // to result in mostly roots and fifths (which is no bad thing if we're aiming to imitatate western melodies)
  for( int channel = 0; channel < CHANNELS; channel ++ )
  {
    int a  = 0;
    int s = 0;
    int root_fourth_fifth = 0; // 0 = root, 3 = fourth, 4 = fifth
    
    for( int i = 0; a < NUM_ACTIVES; i ++ )
    {
    
      // favour root and fifth notes
      if( bitIsSet( latWhiskers, i ) )
      { // if the latitude bits are set - alternate between placing a root or fifth note
        activeNotes[channel][a] = scales[scale][root_fourth_fifth] + rootNote;
        
        // alternate between picking a root or fifth
        if (root_fourth_fifth == 0) 
          root_fourth_fifth = 4;
        else 
          root_fourth_fifth = 0;

        a++;
      }
      else
      { // otherwise ascend through the scale as normal
        activeNotes[channel][a] = scales[scale][s] + rootNote;
        a++;
      }
       
       s++;
       if(  scales[scale][s] > 250 )
       {
         s = 0;
         rootNote += 12;
       }
    
    }
    
    numActives[channel] = a;
    
    for( ; a < NUM_ACTIVES; a ++ )
      activeNotes[channel][a] = 0;


  #ifdef DO_LOGGING
    Serial.print ("Chanl "); Serial.print (channel, DEC);
    Serial.print (" activenotes: ");
    for( int i = 0; i < NUM_ACTIVES; i ++ ){
      Serial.print (activeNotes[channel][i], DEC);
    }
  #endif
  }// channel loop
  
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
   
   int beatMillisecs = 200 + (5 * bitList( latWhiskers, "0000 0000 0000 0000 0000 0000 1111" ));  // vary smoothly with latitude

   int numBeats; // = 3 + bitList( lonWhiskers, "0000 0000 0000 0000 0000 0001 1111" ); // 0 to 32
   
   int barLength = 16; //4 + countBits( bitList( lonWhiskers, "0000 0000 0000 0000 0000 0000 0110" )); 
   int numBars = 4;
   int beatsBerDoof = 4;
   
   numBeats = numBars * barLength;
   
   //unsigned long beatMask = (bitList( lonWhiskers, "0000 0000 0000 1111 1111 1111 1111" ) << 16)
   //                          | (bitList( latWhiskers, "0000 0000 0000 1111 1111 1111 1111" ));
   
   unsigned long beatMask = mixBits( lonWhiskers,  latWhiskers );  // alternate bits from the bottom 16 of the two coords
   unsigned long otherBeatMask = bitList(beatMask, "0101 0101 0101 0101 0101 0101 0101" ); 
 
   int melodyModulus = countBits(bitList( lonWhiskers, "0000 0000 0000 0000 0000 0011 1111" ));
   melodyModulus = 1 + (melodyModulus % (numActives[1] - 1)); // guarantee nonzero
   
   tuneDelete();
    
   tuneSetBeatInterval( beatMillisecs ); 
   tuneSetBarLength( barLength );
    int volume;
   int beat;

   int melodyModulatron = 0;
   for( beat = 0; beat < numBeats && beat < TUNE_LIST_SIZE; beat ++ )
   {
       int beatOfBar = (beat % barLength);
       boolean firstBeat = ( beatOfBar == 0 ) ; // stress the first note of the 'bar'
       boolean doofBeat = (beatOfBar % beatsBerDoof) == 0;
       
       // drum line on channel 0
       if( doofBeat )
         doof( beat );
       else
         if( bitIsSet( beatMask, beatOfBar ))        // note the use of 'beat of bar' instead of 'beat', so the doof-tish line always repeatsin each bar
           if( bitIsSet( otherBeatMask, beatOfBar ))
             doof( beat );
           else
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
        /* phill temporary - don't repeat bars
        if( beatOfBar >= barLength / 2 )  // so all bars start the same but vary at the end
          b = beat;
        */ 
        
        // chaotically pick notes from the "allowed notes" activeNotes list
        melodyModulatron = (melodyModulatron + melodyModulus) % numActives[channel];
      
        if( firstBeat )
        { // always start from the root note
           tuneAddNote( activeNotes[channel][0], 
                       volume, delta, beat, channel);
        }
        else if (bitIsSet( otherBeatMask, beatOfBar ) // use beatOfBar not beat so the timing of notes is constant across bars even when the note  choice isn't
                    && beatOfBar<(numBeats-4))
        {
           tuneAddNote( activeNotes[channel][melodyModulatron], 
                       volume, delta, beat, channel);
        }
        
        
        /* phill - temporary climb up the "allowed notes" on every beat (for debugging purposes)
         melodyModulatron = (melodyModulatron + 1) % numActives[channel];
         tuneAddNote( activeNotes[channel][melodyModulatron], 
                       volume, delta, beat, channel);
        */

   }
 }
 
 void doof( int beat )  // assuming  VOICE_VIBRA and ENVELOPE_EXP, this makes a drum-ish doof on channel 0
 {
   tuneAddNote( 20, MAXVOLUME, ENVELOPE_DELTA_SHORT, beat,  0);
 }
 
 void tish( int beat )
 {
   tuneAddNote( 40, MAXVOLUME, ENVELOPE_DELTA_TINY, beat,  0);
 }
 
 void buildNoGpsTune()
 {
   
   tuneDelete();
   
   tuneSetBeatInterval( 1000 / (1 + gpsStatus));  // gets faster as it gets better
  
   int beat;
   for( beat = 0; beat < 3; beat ++ )
   {

      tuneAddNote( 50 - beat,  MAXVOLUME - beat, ENVELOPE_DELTA_SHORT, beat, 1 );
      
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
   


