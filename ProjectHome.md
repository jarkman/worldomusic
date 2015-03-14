World'O'Music - GPS-based generative music on Arduino

This is a device which plays a tune generated from its position. It plays a different tune, roughly, for every square foot of the planet, and the tune generation is written so that over small movements the tune changes smoothly.

Here is is on its first day out, at Chapter in Cardiff:

http://lh4.ggpht.com/_PBDnF38pZCU/SuNw8dz3jTI/AAAAAAAAHkQ/KEtYMQqYxXQ/s400/DSC04711.JPG

And here's what's inside:

http://lh4.ggpht.com/_PBDnF38pZCU/SuNw492VMaI/AAAAAAAAHkI/mT6U9rne8Cs/s400/DSC04707.JPG

This project is derived from the Pisan-O-Matic:
http://code.google.com/p/pisanomatic/
and the GPS-A-Min:
http://jarkman.co.uk/catalog/robots/gpsamin.htm


Hardware for this is identical to the GPS-A-Min:

One Arduino Duemilanove (the 328 version). Any other Arduino-compatible board that is at least as fast as the 328 should be fine.

One GPS module with NMEA output. I used the LS20031:
http://www.coolcomponents.co.uk/catalog/product_info.php?cPath=21&products_id=210

One cheap MP3 amp/speaker. Mine cost £6 from Tesco.

A pack of eight AA NiMh batteries (2000 mAh) will run it for a few hours.

As with the GPS-A-Min, the amp input is wired to pin 3 of the Arduino, the PWM output, and the GPS module TX & RX are wired to RX & TX on the Arduino. Note that these pins are also used by the Arduino's USB interface, so you need to disconnect the GPS in order to program the Arduino.
