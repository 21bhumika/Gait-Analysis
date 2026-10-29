import processing.serial.*;

int screen = 0;  // 0=home  1=sensor analysis

void setup() {
  size(1100, 700);
  initSerial();
}

void draw() {
  switch (screen) {
    case 0: drawHome(); break;
    case 1: drawSensorAnalysis(); break;
  }
}

void mousePressed() {
  switch (screen) {
    case 0: homeClick(); break;
    case 1: sensorClick(); break;
  }
}
