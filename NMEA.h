
#define GPS_STATUS_NO_COMMS 0
#define GPS_STATUS_BAD_COMMS 1
#define GPS_STATUS_NO_FIX 2
#define GPS_STATUS_FIX 3

extern int gpsStatus; 
extern float lat; // store the Latitude from the gps, in decimal degrees
extern float lon;// Store guess what?
extern unsigned long latWhiskers;  // in whiskers, which are 0.0001 minutes
extern unsigned long lonWhiskers;
extern float alt_MSL; //This is the alt.
extern float ground_speed;// This is the velocity your "plane" is traveling in meters for second, 1Meters/Second= 3.6Km/H = 1.944 knots
extern float ground_course;//This is the runaway direction of you "plane" in degrees
extern float climb_rate; //This is the velocity you plane will impact the ground (in case of being negative) in meters for seconds
extern int numSatellites;

extern void Wait_GPS_Fix(void);


