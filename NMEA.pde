// NMEA parsing from ArduPilot 2.2.3

// also see http://diydrones.com/profiles/blogs/using-the-5hz-locosys-gps-with

/***************************************************************************
 NMEA variables
 **************************************************************************/

/*GPS Pointers*/ 
char *token; //Some pointers
char *search = ",";
char *brkb, *pEnd;
char gps_buffer[100]; //The tradional buffer.


long refresh_rate=0;


int gpsStatus = GPS_STATUS_NO_COMMS;

float lat=0; // store the Latitude from the gps
float lon=0;// Store guess what?

unsigned long latWhiskers =0L;  // in whiskers, which are 0.0001 minutes
unsigned long lonWhiskers =0L;

float alt_MSL=0; //This is the alt.
float ground_speed=0;// This is the velocity your "plane" is traveling in meters for second, 1Meters/Second= 3.6Km/H = 1.944 knots
float ground_course=0;//This is the runaway direction of you "plane" in degrees
float climb_rate=0; //This is the velocity you plane will impact the ground (in case of being negative) in meters for seconds
char data_update_event=0; 
int numSatellites = 0;

const float t7=1000000.0;

//GPS Locosys configuration strings...
#define USE_SBAS 0
#define SBAS_ON "$PMTK313,1*2E\r\n"
#define SBAS_OFF "$PMTK313,0*2F\r\n"

#define NMEA_OUTPUT_5HZ "$PMTK314,0,5,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n" //Set GGA and RMC to 5HZ  
#define NMEA_OUTPUT_4HZ "$PMTK314,0,4,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n" //Set GGA and RMC to 4HZ 
#define NMEA_OUTPUT_3HZ "$PMTK314,0,3,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n" //Set GGA and RMC to 3HZ 
#define NMEA_OUTPUT_2HZ "$PMTK314,0,2,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n" //Set GGA and RMC to 2HZ 
#define NMEA_OUTPUT_1HZ "$PMTK314,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n" //Set GGA and RMC to 1HZ

#define LOCOSYS_REFRESH_RATE_200 "$PMTK220,200*2C\r\n" //200 milliseconds 
#define LOCOSYS_REFRESH_RATE_250 "$PMTK220,250*29\r\n" //250 milliseconds
#define LOCOSYS_REFRESH_RATE_250 "$PMTK220,250*29\r\n" //250 milliseconds

#define LOCOSYS_BAUD_RATE_4800 "$PMTK251,4800*14\r\n"
#define LOCOSYS_BAUD_RATE_9600 "$PMTK251,9600*17\r\n"
#define LOCOSYS_BAUD_RATE_19200 "$PMTK251,19200*22\r\n"
#define LOCOSYS_BAUD_RATE_38400 "$PMTK251,38400*27\r\n"
#define LOCOSYS_BAUD_RATE_57600 "$PMTK251,57600*2\r\n"
#define LOCOSYS_BAUD_RATE_115200 "$PMTK251,115200*1F\r\n"

#define LOCOSYS_FACTORY_RESET "$PMTK104*37\r\n"

float dec_min_to_dec_deg(char *token );
unsigned long dec_min_to_whiskers(char *token );


//#define LOCOSYS_SELECT_FIELDS "$PMTK314,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n" // this should turn Off all sentences except GGA and RMC
// duplicated by NMEA_OUTPUT_5HZ above

/****************************************************************
 Parsing stuff for NMEA
 ****************************************************************/
void init_gps(void)
{
  pinMode(13, OUTPUT);//Status led
  
  #ifndef DO_LOGGING
  //Serial.begin(57600); // according to Cool Components this is th default for the LS20031
  Serial.begin(9600); 
  delay(1000);
  
  Serial.print(LOCOSYS_BAUD_RATE_38400);
  Serial.begin(38400);
  delay(500);
 
  Serial.print(LOCOSYS_BAUD_RATE_57600);
  Serial.begin(57600);
  delay(500);
   
  //Serial.print(LOCOSYS_BAUD_RATE_115200);
  //Serial.begin(115200);
  //delay(500);

  //Serial.print(LOCOSYS_FACTORY_RESET);

  Serial.print(LOCOSYS_REFRESH_RATE_200);
  
  delay(500);
  Serial.print(NMEA_OUTPUT_5HZ);
  delay(500);
  Serial.print(SBAS_OFF);
  
  #endif
  
  
  
  //Wait_GPS_Fix();
}

void fast_init_gps(void)
{
  
  //Serial.begin(9600); //Universal Sincronus Asyncronus Receiveing Transmiting 
  //Serial.begin(38400);
}
/* sample output from LS20031

$GPGGA,184147.800,5142.0313,N,00302.5582,W,1,3,10.94,100.6,M,49.6,M,,*72
$GPGLL,5142.0313,N,00302.5582,W,184147.800,A,A*44
$GPGSA,A,2,21,24,18,,,,,,,,,,10.98,10.94,1.00*02
$GPGSV,2,1,06,16,62,172,,21,43,062,44,18,34,106,44,19,30,273,*7F
$GPGSV,2,2,06,24,05,049,28,15,01,047,*7D
$GPRMC,184147.800,A,5142.0313,N,00302.5582,W,3.60,253.14,230809,,,A*77
$GPVTG,253.14,T,,M,3.60,N,6.68,K,A*31
$GPGGA,184148.000,5142.0312,N,00302.5588,W,1,3,10.94,100.6,M,49.6,M,,*7E
$GPGLL,5142.0312,N,00302.5588,W,184148.000,A,A*48
$GPGSA,M,2,21,24,18,,,,,,,,,,10.99,10.94,1.00*0F
$GPGSV,2,1,06,16,62,172,,21,43,062,44,18,34,106,44,19,30,273,*7F
$GPGSV,2,2,06,24,05,049,28,15,01,047,*7D
$GPRMC,184148.000,A,5142.0312,N,00302.5588,W,3.53,252.28,230809,,,A*75
$GPVTG,252.28,T,,M,3.53,N,6.53,K,A*37
$GPGGA,184148.200,5142.0311,N,00302.5588,W,1,3,10.94,100.6,M,49.6,M,,*7F
$GPGLL,5142.0311,N,00302.5588,W,184148.200,A,A*49

In a line like this:
$GPRMC,184147.800,A,5142.0313,N,00302.5582,W,3.60,253.14,230809,,,A*77

5142.0313,N    - last digit varies in increments of 1, so resolution is 0.0001 minutes or 0.0000017 degrees or 0.17m
00302.5582,W   - last digit varies in increments of 2, so resolution is 0.0002 minutes or 0.0000033 degrees

These are in deg, min . decimal min format.
Lat, long figures in the app have been converted to decimal degrees by the code below, 
so to get one note increment per resolution increment, multiply lat/long by 600,000.
*/

void decode_gps(void)
{
  #ifdef SIMULATE_GPS
    simulate_gps();
    return;
  #endif
  
  #ifdef DO_LOGGING
    // no point trying to se the serial port when logging is on
    return;
  #endif
    
  const char head_rmc[]="GPRMC"; //GPS NMEA header to look for
  const char head_gga[]="GPGGA"; //GPS NMEA header to look for
  
  static unsigned long GPS_timer=0; //used to turn off the LED if no data is received. 
  
  static byte unlock=1; //some kind of event flag
  static byte checksum=0; //the checksum generated
  static byte checksum_received=0; //Checksum received
  static byte counter=0; //general counter

  //Temporary variables for some tasks, specially used in the GPS parsing part (Look at the NMEA_Parser tab)
  unsigned long temp=0;
  unsigned long temp2=0;
  unsigned long temp3=0;


  while(Serial.available() > 0)
  {
      
    if(unlock==0)
    {
      gps_buffer[0]=Serial.read();//puts a byte in the buffer
  
      if(gps_buffer[0]=='$')//Verify if is the preamble $
      {
        unlock=1; 
      }
    }
    /*************************************************/
    else
    {
      gps_buffer[counter]=Serial.read();


      if(gps_buffer[counter]==0x0A)//Looks for \F
      {

        unlock=0;

       if( gpsStatus == GPS_STATUS_NO_COMMS )
          gpsStatus = GPS_STATUS_BAD_COMMS;
          

        if (strncmp (gps_buffer,head_rmc,5) == 0)//looking for rmc head, for lat/long, speed, and course
        {

          /*Generating and parsing received checksum, */
          for(int x=0; x<100; x++)
          {
            if(gps_buffer[x]=='*')
            { 
              checksum_received=strtol(&gps_buffer[x+1],NULL,16);//Parsing received checksum...
              break; 
            }
            else
            {
              checksum^=gps_buffer[x]; //XOR the received data... 
            }
          }

          if(checksum_received==checksum)//Checking checksum
          {
            /* Token will point to the data between comma "'", returns the data in the order received */
            /*THE GPRMC order is: UTC, UTC status ,Lat, N/S indicator, Lon, E/W indicator, speed, course, date, mode, checksum*/
            token = strtok_r(gps_buffer, search, &brkb); //Contains the header GPRMC, not used

            token = strtok_r(NULL, search, &brkb); //UTC Time, not used
            //time=  atol (token);
            token = strtok_r(NULL, search, &brkb); //Valid UTC data? maybe not used... 


            //Longitude in degrees, decimal minutes. (ej. 4750.1234 degrees decimal minutes = 47.835390 decimal degrees)
            //Where 47 are degrees and 50 the minutes and .1234 the decimals of the minutes.
            //To convert to decimal degrees, devide the minutes by 60 (including decimals), 
            //Example: "50.1234/60=.835390", then add the degrees, ex: "47+.835390=47.835390" decimal degrees
            token = strtok_r(NULL, search, &brkb); //Contains Latitude in degrees decimal minutes... 

            lat = dec_min_to_dec_deg( token );
            latWhiskers = dec_min_to_whiskers( token );
            /*
            //taking only degrees, and minutes without decimals, 
            //strtol stop parsing till reach the decimal point "."  result example 4750, eliminates .1234
            temp=strtol (token,&pEnd,10);

            //takes only the decimals of the minutes
            //result example 1234. 
            temp2=strtol (pEnd+1,NULL,10);

            //joining degrees, minutes, and the decimals of minute, now without the point...
            //Before was 4750.1234, now the result example is 47501234...
            temp3=(temp*10000)+(temp2);


            //modulo to leave only the decimal minutes, eliminating only the degrees.. 
            //Before was 47501234, the result example is 501234.
            temp3=temp3%1000000;


            //Dividing to obtain only the de degrees, before was 4750 
            //The result example is 47 (4750/100=47)
            temp/=100;

            //Joining everything and converting to float variable... 
            //First i convert the decimal minutes to degrees decimals stored in "temp3", example: 501234/600000= .835390
            //Then i add the degrees stored in "temp" and add the result from the first step, example 47+.835390=47.835390 
            //The result is stored in "lat" variable... 
            lat=temp+((float)temp3/600000);
            */

            token = strtok_r(NULL, search, &brkb); //lat, north or south?
            //If the char is equal to S (south), multiply the result by -1.. 
            if(*token=='S'){
              lat=lat*-1;
              latWhiskers += 0x8000000L;
            }

            //This the same procedure use in lat, but now for Lon....
            token = strtok_r(NULL, search, &brkb);
            lon = dec_min_to_dec_deg( token );
            lonWhiskers = dec_min_to_whiskers( token );

            /*
            temp=strtol (token,&pEnd,10); 
            temp2=strtol (pEnd+1,NULL,10); 
            temp3=(temp*10000)+(temp2);
            temp3=temp3%1000000; 
            temp/=100;
            lon=temp+((float)temp3/600000);
            */
            
            token = strtok_r(NULL, search, &brkb); //lon, east or west?
            if(*token=='W'){
              lon=lon*-1;
              lonWhiskers += 0x8000000L;
            }

            token = strtok_r(NULL, search, &brkb); //Speed overground?
            ground_speed= atoi(token);

            token = strtok_r(NULL, search, &brkb); //Course?
            ground_course= atoi(token);

            if( gpsStatus == GPS_STATUS_NO_COMMS )
              gpsStatus = GPS_STATUS_NO_FIX; // got data, at least
              
            data_update_event|=0x01; //Update the flag to indicate the new data has arrived. 
          }
          checksum=0;
        }//End of the GPRMC parsing

        if (strncmp (gps_buffer,head_gga,5) == 0)//now looking for GPGGA head, for fix quality and altitude
        {
          /*Generating and parsing received checksum, */
          for(int x=0; x<100; x++)
          {
            if(gps_buffer[x]=='*')
            { 
              checksum_received=strtol(&gps_buffer[x+1],NULL,16);//Parsing received checksum...
              break; 
            }
            else
            {
              checksum^=gps_buffer[x]; //XOR the received data... 
            }
          }

          if(checksum_received==checksum)//Checking checksum
          {

            token = strtok_r(gps_buffer, search, &brkb);//GPGGA header, not used anymore
            token = strtok_r(NULL, search, &brkb);//UTC, not used!!
            token = strtok_r(NULL, search, &brkb);//lat, not used!!
            token = strtok_r(NULL, search, &brkb);//north/south, nope...
            token = strtok_r(NULL, search, &brkb);//lon, not used!!
            token = strtok_r(NULL, search, &brkb);//wets/east, nope
            
            token = strtok_r(NULL, search, &brkb);//Position fix, used!!
            
            int fixQuality =atoi(token); 
            if(fixQuality != 0) // 0 - no fix, 1 and up - various sorts of fix
              gpsStatus = GPS_STATUS_FIX; // got a fix
            else
              gpsStatus = GPS_STATUS_NO_FIX; // got data, at least
              
              
            token = strtok_r(NULL, search, &brkb); //satellites in use!! 
            numSatellites =atoi(token); 
            
            token = strtok_r(NULL, search, &brkb);//HDOP, not needed
            token = strtok_r(NULL, search, &brkb);//ALTITUDE, is the only meaning of this string.. in meters of course. 
            alt_MSL=atoi(token);
            if(alt_MSL<0){
              alt_MSL=0;
            }

            if(gpsStatus != GPS_STATUS_FIX) 
            {
                

              digitalWrite(13,HIGH); //Status LED...
            }
            else 
            {
               

              digitalWrite(13,LOW);
            }
            data_update_event|=0x02; //Update the flag to indicate the new data has arrived.
          }
          checksum=0; //Restarting the checksum
        }

        for(int a=0; a<=counter; a++)//restarting the buffer
        {
          gps_buffer[a]=0;
        } 
        counter=0; //Restarting the counter
        GPS_timer=millis(); //Restarting timer...
      }
      else
      {
        counter++; //Incrementing counter
      }
    }
  }
  
  if(millis() - GPS_timer > 2000){
      digitalWrite(13, LOW);  //If we don't receive any byte in two seconds turn off gps fix LED... 
      //gpsStatus = GPS_STATUS_NO_COMMS; 
    }  
}

#ifdef SIMULATE_GPS

// phill temporary - changed this so we jump around a lot to begin with, then settle down in the 5142 area

 char* simLatStrings[] = { 
                           "42.0612",
                           "6142.0614",
                           "2142.0900",
                           "002.0955",
                           "5142.0314",
                           "5142.0315",
                           "5142.0316",
                           "5142.0412",
                            NULL } ;
                            
 char* simLonStrings[] = { "00302.5582",
                           "00302.5583",
                           "00302.5584",
                           "00302.5585",
                           "00302.5222",
                           "00302.5100",
                           "00302.5022",
                           "00302.5945",
                           NULL };                        
 
 /* hold still on the longitude                          
 char* simLonStrings[] = { "00302.5582",
                           "00302.5582",
                           "00302.5582",
                           "00302.5582",
                           "00302.5582",
                           "00302.5582",
                           "00302.5582",
                           "00302.5582",
                           NULL };
 */


void simulate_gps()
{
  static long nextGPSSimTime = 0;
  static int nextString = -2;
  
  long now = millis();
  
  if( now < nextGPSSimTime )
    return; 
    
  // eg: lat 5142.0313  lon 00302.5582
   
  nextString ++;
  
   if( nextString < 0 )
   {
     gpsStatus = GPS_STATUS_NO_FIX;
     return;
   }
   
   gpsStatus = GPS_STATUS_FIX;
   
   if( simLatStrings[nextString] == NULL )
     nextString = 0;
   
  latWhiskers = dec_min_to_whiskers( simLatStrings[nextString] );
  lonWhiskers = dec_min_to_whiskers( simLonStrings[nextString] );
  lonWhiskers += 0x8000000L; // typically west
  
  nextGPSSimTime = now + 15000; // move to new place every 15 secs

   
  #ifdef DO_LOGGING
     Serial.print ("simulate_gps - lat, lon: ");
           Serial.print ("\n");
      Serial.print (simLatStrings[nextString]); 
            Serial.print ("\n");
     Serial.print (simLonStrings[nextString]); 
           Serial.print ("\n");
     
     Serial.print (latWhiskers); 
           Serial.print ("\n");
      Serial.print (lonWhiskers); 
      Serial.print ("\n");
    #endif
    
}
#endif

unsigned long dec_min_to_whiskers(char *token ) // where a whisker is 0.0001 minutes, which is our resolution
{
   unsigned long temp=0;
   unsigned long whiskers=0;
   unsigned long temp3=0;
  
   //Token contains lat/lon in degrees, decimal minutes. 
   // (eg. 4750.1234 degrees decimal minutes = 47.835390 decimal degrees)
   //Where 47 are degrees and 50 the minutes and .1234 the decimals of the minutes.

 
   //taking only degrees, and minutes without decimals, 
   //strtol stop parsing till reach the decimal point "."  result example 4750, eliminates .1234
   temp=strtol (token,&pEnd,10);  // 4750
   
   unsigned long degs = temp / 100L;  // 47
   unsigned long minutes = temp % 100L;  // 50
   
   //takes only the decimals of the minutes
   //result example 1234. 
   whiskers=strtol (pEnd+1,NULL,10);  // 1234

   //joining degrees, minutes, and the decimals of minute, now without the point...
   //Before was 4750.1234, now the result example is 47501234...
   whiskers += minutes * 10000L;   // 501234
   
   whiskers += degs * 60L * 10000L; // 28,701,234


   
   return whiskers;  // max value is 108,000,000 0x66ff300, 27 bits, plus we will add a N/S or E/W to get 28 bits
}  

float dec_min_to_dec_deg(char *token )
{
   unsigned long temp=0;
  unsigned long temp2=0;
  unsigned long temp3=0;
  
   //Token contains lat/lon in degrees, decimal minutes. 
   // (ej. 4750.1234 degrees decimal minutes = 47.835390 decimal degrees)
   //Where 47 are degrees and 50 the minutes and .1234 the decimals of the minutes.
   //To convert to decimal degrees, devide the minutes by 60 (including decimals), 
   //Example: "50.1234/60=.835390", then add the degrees, ex: "47+.835390=47.835390" decimal degrees

 
   //taking only degrees, and minutes without decimals, 
   //strtol stop parsing till reach the decimal point "."  result example 4750, eliminates .1234
   temp=strtol (token,&pEnd,10);

   //takes only the decimals of the minutes
   //result example 1234. 
   temp2=strtol (pEnd+1,NULL,10);

   //joining degrees, minutes, and the decimals of minute, now without the point...
   //Before was 4750.1234, now the result example is 47501234...
   temp3=(temp*10000)+(temp2);


   //modulo to leave only the decimal minutes, eliminating only the degrees.. 
   //Before was 47501234, the result example is 501234.
   temp3=temp3%1000000;


   //Dividing to obtain only the de degrees, before was 4750 
   //The result example is 47 (4750/100=47)
   temp/=100;

   //Joining everything and converting to float variable... 
   //First i convert the decimal minutes to degrees decimals stored in "temp3", example: 501234/600000= .835390
   //Then i add the degrees stored in "temp" and add the result from the first step, example 47+.835390=47.835390 
   //The result is stored in "lat" variable... 
   float deg = temp+((float)temp3/600000);
            
   return deg;
}
            



void Wait_GPS_Fix(void)//Wait GPS fix...
{
  do
  {
    decode_gps();
    digitalWrite(13,HIGH);
    delay(250);
    digitalWrite(13,LOW);
    delay(500);
  }
  while(gpsStatus != GPS_STATUS_FIX);// loop till we get a fix


  do
  {
    decode_gps(); //Reading and parsing GPS data  
    digitalWrite(13,HIGH);
    delay(250);
    digitalWrite(13,LOW);
    delay(250);
  }
  while((data_update_event&0x01!=0x01)&(data_update_event&0x02!=0x02));

}

/*
void print_data(void)
{
  static byte counter;

    if(counter >= 1000)//If to reapeat every second.... 
    {
      Serial.print("!!!");
      Serial.print("LAT:");
      Serial.print((long)((float)lat*(float)t7));
      Serial.print(",LON:");
      Serial.print((long)((float)lon*(float)t7)); //wp_current_lat
       //Serial.print(",WLA:");
      //Serial.print((long)((float)wp_current_lat*(float)t7));
      //Serial.print(",WLO:");
      //Serial.print((long)((float)wp_current_lon*(float)t7));
      Serial.print (",SPD:");
      Serial.print(ground_speed);    
      
      Serial.println(",***");
      counter=0;
      
      //Serial.println(refresh_rate);
      refresh_rate=0;
    }
    else
    {
    counter++;
    }
    
   
}
*/
