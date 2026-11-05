import processing.serial.*;
import processing.sound.*;   // must be in a .pde tab so the Sound library is on the classpath

int screen = 0;  // 0=home  1=sensor analysis  2=cool application  3=sensor profiles

void setup() {
  size(1100, 700);
  initProfiles();
  initSerial();
}

void draw() {
  switch (screen) {
    case 0: drawHome(); break;
    case 1: drawSensorAnalysis(); break;
    case 2: drawCoolApp(); break;
    case 3: drawProfileScreen(); break;
    case 4: drawJumpAnalysis(); break;
  }
}

void mousePressed() {
  switch (screen) {
    case 0: homeClick(); break;
    case 1: sensorClick(); break;
    case 2: coolClick(); break;
    case 3: profileClick(); break;
    case 4: jumpClick(); break;
  }
}

void keyPressed() {
  if (screen == 3) profileKey();
  else if (screen == 2) coolKey();
}
