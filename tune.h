// tune.h  - header for tune.pde, which represents a series of notes from several voices spread out in time

extern void initTune(); // called from setup - clean up our data structures

extern void tuneDelete(); // destroy the existing tune


extern void tuneAddNote( int noteNumber, int beat, int voice );

extern void progressTune(); // called from loop() repeatedly - work out if a note is due, and start it


extern void tuneSetBeatInterval( int time );
