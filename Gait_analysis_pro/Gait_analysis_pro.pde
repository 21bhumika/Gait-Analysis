import processing.serial.*;

int screen = 0;  // 0=home  1=sensor analysis  3=sensor profiles

void setup() {
  size(1100, 700);
  initProfiles();
  initSerial();
}

void draw() {
  switch (screen) {
    case 0: drawHome(); break;
    case 1: drawSensorAnalysis(); break;
    case 3: drawProfileScreen(); break;
  }
}

void mousePressed() {
  switch (screen) {
    case 0: homeClick(); break;
    case 1: sensorClick(); break;
    case 3: profileClick(); break;
  }
}

void keyPressed() {
  if (screen == 3) profileKey();
}
