#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

Adafruit_MPU6050 mpu;

const int FSR_MF = A0;

const int FSR_LF = A1;

const int FSR_MM = A2;

const int FSR_HEEL = A3;

const int LED_MF   = 3;
const int LED_LF   = 5;
const int LED_MM   = 6;
const int LED_HEEL = 9;

int fsrMF = 0;
int fsrLF = 0;
int fsrMM = 0;
int fsrHeel = 0;

float az = 0;
float ay = 0;
float ax = 0;

float gxc = 0;
float gyc = 0;
float gzc = 0;

const int FSR_MAX = 900;

const float GYRO_BIAS_X = -0.13;
const float GYRO_BIAS_Y =  0.02;
const float GYRO_BIAS_Z = -0.01;

const float GYRO_THRESHOLD        = 0.15;
const float ACCEL_DELTA_THRESHOLD = 0.30;
const unsigned long MOTION_CHECK_PERIOD = 50;
const unsigned long MOTION_HOLD_MS      = 500;

float prevAx = 0, prevAy = 0, prevAz = 0;
bool havePrev = false;
float gyroMag = 0;
float accelDelta = 0;
unsigned long lastMotionCheck = 0;
unsigned long lastMotionSeen = 0;

bool inMotion = false;

unsigned long motionStartTime = 0;

unsigned long totalActivityTime = 0;

unsigned long lastSend = 0;

const unsigned long SEND_PERIOD = 40;

const int FSR_DEADZONE = 15;

int readFSR(int pin) {
  analogRead(pin);              // throwaway read: lets the ADC settle
  delayMicroseconds(100);
  int v = analogRead(pin);
  v -= FSR_DEADZONE;
  return (v < 0) ? 0 : v;
}

char *addFloat(char *p, float value, byte decimals) {
  dtostrf(value, 1, decimals, p);
  p += strlen(p);
  *p++ = ',';
  return p;
}

void setup() {
  Serial.begin(115200);
  Wire.begin();
#if defined(ARDUINO_ARCH_AVR)
  Wire.setWireTimeout(3000, true);
#endif

  pinMode(LED_MF, OUTPUT);
  pinMode(LED_LF, OUTPUT);
  pinMode(LED_MM, OUTPUT);
  pinMode(LED_HEEL, OUTPUT);

  analogWrite(LED_MF, 0);
  analogWrite(LED_LF, 0);
  analogWrite(LED_MM, 0);
  analogWrite(LED_HEEL, 0);

  if (!mpu.begin()) {
    Serial.println("ERROR: MPU6050 not found");
    while (1) {
      delay(10);
    }
  }

  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);

  mpu.setGyroRange(MPU6050_RANGE_2000_DEG);

  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);

  Serial.println("System ready");
}

void loop() {

  fsrMF   = readFSR(FSR_MF);
  fsrLF   = readFSR(FSR_LF);
  fsrMM   = readFSR(FSR_MM);
  fsrHeel = readFSR(FSR_HEEL);

  const int RANGE = FSR_MAX - FSR_DEADZONE;

  int ledMF   = map(constrain(fsrMF,   0, RANGE), 0, RANGE, 0, 255);
  int ledLF   = map(constrain(fsrLF,   0, RANGE), 0, RANGE, 0, 255);
  int ledMM   = map(constrain(fsrMM,   0, RANGE), 0, RANGE, 0, 255);
  int ledHeel = map(constrain(fsrHeel, 0, RANGE), 0, RANGE, 0, 255);

  analogWrite(LED_MF, ledMF);
  analogWrite(LED_LF, ledLF);
  analogWrite(LED_MM, ledMM);
  analogWrite(LED_HEEL, ledHeel);

  sensors_event_t a;
  sensors_event_t g;
  sensors_event_t temp;

  mpu.getEvent(&a, &g, &temp);

  ax = a.acceleration.x;
  ay = a.acceleration.y;
  az = a.acceleration.z;

  if (millis() - lastMotionCheck >= MOTION_CHECK_PERIOD) {

    lastMotionCheck = millis();

    gxc = g.gyro.x - GYRO_BIAS_X;
    gyc = g.gyro.y - GYRO_BIAS_Y;
    gzc = g.gyro.z - GYRO_BIAS_Z;
    gyroMag = sqrt(gxc * gxc + gyc * gyc + gzc * gzc);

    accelDelta = havePrev? (fabs(ax - prevAx) + fabs(ay - prevAy) + fabs(az - prevAz)): 0;

    prevAx = ax;
    prevAy = ay;
    prevAz = az;
    havePrev = true;

    if (gyroMag > GYRO_THRESHOLD || accelDelta > ACCEL_DELTA_THRESHOLD) {
      lastMotionSeen = millis();
    }
  }

  bool newMotionState = (lastMotionSeen != 0) && (millis() - lastMotionSeen < MOTION_HOLD_MS);

  if (newMotionState && !inMotion) {
    motionStartTime = millis();
  }
  if (!newMotionState && inMotion) {
    totalActivityTime += millis() - motionStartTime;
  }
  inMotion = newMotionState;

  unsigned long currentActivityTime = totalActivityTime;

  if (inMotion) {
    currentActivityTime += millis() - motionStartTime;
  }

  if (millis() - lastSend >= SEND_PERIOD) {
    lastSend = millis();

    // DATA,MF,LF,MM,HEEL,ax,ay,az,motion,activitySeconds,gx,gy,gz,timeMs*checksum

#if defined(ARDUINO_ARCH_AVR)
    if (Wire.getWireTimeoutFlag()) {
      Wire.clearWireTimeoutFlag();
      Serial.println("ERROR: MPU6050 stopped responding (check SDA/SCL wiring)");
      return;
    }
#endif

    static char line[110];
    char *p = line;
    p += sprintf(p, "DATA,%d,%d,%d,%d,", fsrMF, fsrLF, fsrMM, fsrHeel);

    p = addFloat(p, ax, 2);
    p = addFloat(p, ay, 2);
    p = addFloat(p, az, 2);

    p += sprintf(p, "%d,", inMotion ? 1 : 0);

    p = addFloat(p, currentActivityTime / 1000.0, 2);

    p = addFloat(p, g.gyro.x - GYRO_BIAS_X, 3);
    p = addFloat(p, g.gyro.y - GYRO_BIAS_Y, 3);
    p = addFloat(p, g.gyro.z - GYRO_BIAS_Z, 3);

    p += sprintf(p, "%lu", millis());

    byte checksum = 0;
    for (char *c = line; c < p; c++) checksum ^= *c;
    sprintf(p, "*%02X", checksum);

    Serial.println(line);
  }

  delay(2);
}
