import processing.serial.*;
import processing.sound.*;   // must be in a .pde tab so the Sound library is on the classpath

int screen = 0;  // 0=summary  1=gait  2=game  3=profiles  4=jump

void setup() {
  size(1100, 700);
  initTheme();
  initProfiles();
  initSerial();
}

void draw() {
  handCursor = false;
  background(C_BG);

  float settled = constrain((millis() - screenChangedAt) / 220.0, 0, 1);
  float eased = 1 - (1 - settled) * (1 - settled);

  pushMatrix();
  translate(0, (1 - eased) * 14);
  switch (screen) {
    case 0: drawHome(); break;
    case 1: drawSensorAnalysis(); break;
    case 2: drawCoolApp(); break;
    case 3: drawProfileScreen(); break;
    case 4: drawJumpAnalysis(); break;
  }
  popMatrix();

  if (settled < 1) {
    noStroke();
    fill(C_BG, 255 * (1 - eased));
    rect(SIDE_W, 0, width - SIDE_W, height);
  }

  drawSidebar();
  cursor(handCursor ? HAND : ARROW);
}

void mousePressed() {
  if (mouseX < SIDE_W) {
    sidebarClick();
    return;
  }
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
