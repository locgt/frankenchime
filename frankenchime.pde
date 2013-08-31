

#define PINS 5   //how many consecutive analog pins are we reading
#define HISTORYBUF 50  //how many historical samples to keep
#define VARIANCE 2  //how big of a variance do we ignore
#define DEBUG 0    //what is the debug level.  greater means more output
#define COOLDOWN 300  //how many millis before we can detect another strike
#define DELAY 10   //what is the loop delay for sensing
#define MAXDIFF 400  //what sample differential do we consider to be the maximum for the largest chime (400 is tuned to DELAY 10)

int pin[PINS];
unsigned long mils[PINS];
char chime[5]={'A', 'B', 'C', 'D', 'E'};
int history[PINS][HISTORYBUF];

void setup() {
  Serial.begin(19200);
  Serial.println("Ready");
  for (int i=0; i<PINS; i++) {   //initialize the debounce timers
    mils[i]=0;
  }

}

void loop() { 
  //read all pins
  for (int i=0; i<PINS; i++) {
    pin[i]=analogRead(i);
    push(i,pin[i]);
    checkForHit(i);
    if(DEBUG > 0 ) {
      Serial.print("Pin ");
      Serial.print(i, DEC);
      Serial.print(": ");
      Serial.print(pin[i], DEC);
      Serial.print("  ");
    }
  }
  if(DEBUG >0) {Serial.println(" "); }
  delay(DELAY);
}

void checkForHit(int p){
  //Analyze the history for this pin to determin if there is a hit
  //A hit means the current value is less than the previous value by a magnatude
  //greater than VARIANCE
  //this requires the polarity on the magnet to be correct to increase to value as it approaches
  int diff=0;
  int magnitude=0;
  int samples = HISTORYBUF/DELAY; //smaller delay means go back more samples to determine strike force.  delay 10 = 5 samples, delay 100 = .5 samples
  if(pin[p] + VARIANCE < history[p][1]){
    //check for debounce on this pin
    if(mils[p] + COOLDOWN < millis()){  //fresh hit
      mils[p]=millis();  //set timer for debouce/cooldown
      //ok we have a good hit, lets check for magnitude.
      //we are going to do a quick and dirty math comparison on the field strength between two samples
      diff=history[p][1]-history[p][2+samples];

      diff=100/DELAY * diff;
      magnitude=map(diff, 1, MAXDIFF, 1,1024);  //map a potential diff to be from 1 to 1024 to send to the pi
      if (magnitude < 0 ) { magnitude=1; }
      if (magnitude > 1024 ) {magnitude=1024; }
      Serial.print(chime[p]);
      Serial.print(":");
      Serial.println(magnitude, DEC);
      if(DEBUG) {
        Serial.print("\nHIT on pin: ");
        Serial.print(p, DEC);
        Serial.print(" diff: ");
        Serial.print(diff);
        Serial.print(" chime: ");
        Serial.print(chime[p]);
        Serial.print("  magnitude: ");
        Serial.println(magnitude, DEC);
      }
    }
  }
}


void push(int pinnum, int val){
  for(int i=HISTORYBUF-1 ; i > -1; i--){  
    if (i > 0 ) {
      history[pinnum][i]=history[pinnum][i-1];
    }
  }
  history[pinnum][0]=val;

  if (DEBUG > 3) {
    Serial.print("--- History for pin: ");
    Serial.print(pinnum, DEC);
    Serial.println(" ---");
    for(int i=0; i < HISTORYBUF; i++){
      Serial.print(pinnum, DEC);
      Serial.print("  :");
      Serial.println(history[pinnum][i]);
    }    
  }
  return;
}


