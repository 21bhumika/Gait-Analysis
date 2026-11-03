#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// MPU6050
Adafruit_MPU6050 mpu;


// FSR PINS
// Medial Forefoot
const int FSR_MF = A0;

// Lateral Forefoot
const int FSR_LF = A1;

// Medial Mid-foot
const int FSR_MM = A2;

// Heel
const int FSR_HEEL = A3;


// LED PINS
const int LED_MF   = 3;
const int LED_LF   = 5;
const int LED_MM   = 6;
const int LED_HEEL = 9;


// FSR VARIABLES
int fsrMF = 0;
int fsrLF = 0;
int fsrMM = 0;
int fsrHeel = 0;


// Maximum ADC value expected under pressure.
// We can calibrate this later.
const int FSR_MAX = 900;


// =====================================================
// MOTION DETECTION (gyro + accel change)
// =====================================================

// Gyro bias measured at rest (rad/s)
const float GYRO_BIAS_X = -0.13;
const float GYRO_BIAS_Y =  0.02;
const float GYRO_BIAS_Z = -0.01;

const float GYRO_THRESHOLD        = 0.15;  // rad/s (~9 deg/s)
const float ACCEL_DELTA_THRESHOLD = 0.30;  // m/s^2 change per check
const unsigned long MOTION_CHECK_PERIOD = 50;   // ms
const unsigned long MOTION_HOLD_MS      = 500;  // stay "in motion" this long

float prevAx = 0, prevAy = 0, prevAz = 0;
bool havePrev = false;
float gyroMag = 0;
float accelDelta = 0;
unsigned long lastMotionCheck = 0;
unsigned long lastMotionSeen = 0;

bool inMotion = false;

// Time when movement started
unsigned long motionStartTime = 0;

// Total accumulated activity time
unsigned long totalActivityTime = 0;


// TIMING
unsigned long lastSend = 0;

// 50 ms = 20 Hz
const unsigned long SEND_PERIOD = 50;

// Readings below this are treated as noise (ghost readings were ~4)
const int FSR_DEADZONE = 15;

int readFSR(int pin) {
  analogRead(pin);              // throwaway read: lets the ADC settle
  delayMicroseconds(100);
  int v = analogRead(pin);      // real read
  v -= FSR_DEADZONE;
  return (v < 0) ? 0 : v;       // anything under the deadzone becomes 0
}

// SETUP
void setup() {
  Serial.begin(115200);
  Wire.begin();

  // LED setup
  pinMode(LED_MF, OUTPUT);
  pinMode(LED_LF, OUTPUT);
  pinMode(LED_MM, OUTPUT);
  pinMode(LED_HEEL, OUTPUT);


  analogWrite(LED_MF, 0);
  analogWrite(LED_LF, 0);
  analogWrite(LED_MM, 0);
  analogWrite(LED_HEEL, 0);


  // MPU6050 setup
  if (!mpu.begin()) {
    Serial.println("ERROR: MPU6050 not found");
    while (1) {
      delay(10);
    }
  }

  // Accelerometer range
  mpu.setAccelerometerRange(MPU6050_RANGE_4_G);

  // Gyroscope range
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);

  // Digital low-pass filter
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);

  Serial.println("System ready");
}

void loop() {

  // 1. READ FSRs
  fsrMF   = readFSR(FSR_MF);
  fsrLF   = readFSR(FSR_LF);
  fsrMM   = readFSR(FSR_MM);
  fsrHeel = readFSR(FSR_HEEL);

  // 2. CONTROL LEDs
  const int RANGE = FSR_MAX - FSR_DEADZONE;

  int ledMF   = map(constrain(fsrMF,   0, RANGE), 0, RANGE, 0, 255);
  int ledLF   = map(constrain(fsrLF,   0, RANGE), 0, RANGE, 0, 255);
  int ledMM   = map(constrain(fsrMM,   0, RANGE), 0, RANGE, 0, 255);
  int ledHeel = map(constrain(fsrHeel, 0, RANGE), 0, RANGE, 0, 255);

  analogWrite(LED_MF, ledMF);
  analogWrite(LED_LF, ledLF);
  analogWrite(LED_MM, ledMM);
  analogWrite(LED_HEEL, ledHeel);

  // 3. READ MPU6050
  sensors_event_t a;
  sensors_event_t g;
  sensors_event_t temp;

  mpu.getEvent(&a, &g, &temp);

  float ax = a.acceleration.x;
  float ay = a.acceleration.y;
  float az = a.acceleration.z;


    // ===================================================
  // 4. MOTION DETECTION
  // ===================================================

  if (millis() - lastMotionCheck >= MOTION_CHECK_PERIOD) {

    lastMotionCheck = millis();

    // Gyro magnitude with bias removed
    float gxc = g.gyro.x - GYRO_BIAS_X;
    float gyc = g.gyro.y - GYRO_BIAS_Y;
    float gzc = g.gyro.z - GYRO_BIAS_Z;
    gyroMag = sqrt(gxc * gxc + gyc * gyc + gzc * gzc);

    // Accel change since the previous check
    accelDelta = havePrev
      ? fabs(ax - prevAx) + fabs(ay - prevAy) + fabs(az - prevAz)
      : 0;

    prevAx = ax;
    prevAy = ay;
    prevAz = az;
    havePrev = true;

    if (gyroMag > GYRO_THRESHOLD || accelDelta > ACCEL_DELTA_THRESHOLD) {
      lastMotionSeen = millis();
    }
  }

  // "In motion" until MOTION_HOLD_MS after the last trigger
  bool newMotionState =
    (lastMotionSeen != 0) &&
    (millis() - lastMotionSeen < MOTION_HOLD_MS);

  // 5. ACTIVITY TIME
  if (newMotionState && !inMotion) { // Movement just started
    motionStartTime = millis();
  }
  if (!newMotionState && inMotion) { // Movement just stopped
    totalActivityTime +=
      millis() - motionStartTime;
  }
  inMotion = newMotionState;

  // Current activity time including active interval
  unsigned long currentActivityTime = totalActivityTime;

  if (inMotion) {
    currentActivityTime += millis() - motionStartTime;
  }

  // 6. SEND DATA TO PROCESSING
  if (millis() - lastSend >= SEND_PERIOD) {
    lastSend = millis();
    // Format:
    // DATA,MF,LF,MM,HEEL,ax,ay,az,motion,activitySeconds

    Serial.print("DATA,");

    Serial.print(fsrMF);    Serial.print(",");
    Serial.print(fsrLF);    Serial.print(",");
    Serial.print(fsrMM);    Serial.print(",");
    Serial.print(fsrHeel);  Serial.print(",");

    Serial.print(ax, 2);    Serial.print(",");
    Serial.print(ay, 2);    Serial.print(",");
    Serial.print(az, 2);    Serial.print(",");

    Serial.print(inMotion ? 1 : 0);
    Serial.print(",");

    Serial.println(currentActivityTime / 1000.0, 2);
  }  
  
  // // ===================================================
  // // 6. (TEST) PRINT ACCELEROMETER OUTPUTS ONLY
  // // ===================================================

  // if (millis() - lastSend >= SEND_PERIOD) {

  //   lastSend = millis();

  //   Serial.print("ax:");        Serial.print(ax, 2);
  //   Serial.print(" ay:");       Serial.print(ay, 2);
  //   Serial.print(" az:");       Serial.print(az, 2);
  //   Serial.print(" mag:");      Serial.print(accelerationMagnitude, 2);
  //   Serial.print(" magG:");     Serial.print(accelerationMagnitude / 9.81, 3);
  //   Serial.print(" dev:");      Serial.print(motionValue, 2);
  //   Serial.print(" thresh:");   Serial.print(MOTION_THRESHOLD, 2);
  //   Serial.print(" motion:");   Serial.print(inMotion ? 1 : 0);
  //   Serial.print(" gx:");       Serial.print(g.gyro.x, 2);
  //   Serial.print(" gy:");       Serial.print(g.gyro.y, 2);
  //   Serial.print(" gz:");       Serial.print(g.gyro.z, 2);
  //   Serial.print(" tempC:");    Serial.println(temp.temperature, 1);
  // }

    // ===================================================
  // 6. (TEST) PRINT RAW MPU6050 VALUES ONLY
  // ===================================================

  // if (millis() - lastSend >= SEND_PERIOD) {

  //   lastSend = millis();

  //   Serial.print(ax, 2);          Serial.print(",");
  //   Serial.print(ay, 2);          Serial.print(",");
  //   Serial.print(az, 2);          Serial.print(",");
  //   Serial.print(g.gyro.x, 2);    Serial.print(",");
  //   Serial.print(g.gyro.y, 2);    Serial.print(",");
  //   Serial.print(g.gyro.z, 2);    Serial.print(",");
  //   Serial.print(gyroMag, 2);     Serial.print(",");
  //   Serial.print(accelDelta, 2);  Serial.print(",");
  //   Serial.println(inMotion ? 1 : 0);
  // }

  delay(2);
}
