import java.awt.Robot;

final String JUMP       = "JUMP";
final String MOVE_LEFT  = "MOVE_LEFT";
final String MOVE_RIGHT = "MOVE_RIGHT";
final String SPACE      = "SPACE";

final int MODE_STRENUOUS = 0;
final int MODE_RELAXED   = 1;
final int MODE_SPACE     = 2;
int caMode = MODE_STRENUOUS;
final String[] CA_MODE_NAME = { "Mode 1: Strenuous (3 directions)", "Mode 2: Relaxed (3 directions)", "Mode 3: Space only" };

final boolean SPACE_FROM_PAD  = true;
final boolean SPACE_FROM_JUMP = true;

final String[] RELAXED_PAD_NAME   = { "MF", "MM", "LF" };
final int[]    RELAXED_PAD_ACTION = { 0, 1, 2 };
final float RELAXED_ON  = 300;
final float RELAXED_OFF = 150;
boolean[] caPadDown  = new boolean[3];
boolean[] caPadArmed = new boolean[3];
float[]   caPadValue = new float[3];

String[] gestureActions = { JUMP, MOVE_LEFT, MOVE_RIGHT, SPACE };
int[]    actionKeys     = { java.awt.event.KeyEvent.VK_W, java.awt.event.KeyEvent.VK_A,
                            java.awt.event.KeyEvent.VK_D, java.awt.event.KeyEvent.VK_SPACE };
String[] actionKeyNames = { "W", "A", "D", "Space" };

boolean[] held      = new boolean[gestureActions.length];
int[]     releaseAt = new int[gestureActions.length];
final int KEY_HOLD_MS = 80;

Robot robot;
String lastEvent = "waiting for input...";
int lastEventMs = 0;

final float CA_FLIGHT_ACCEL_MAX = 5.0;
final float CA_FLIGHT_GYRO_MAX  = 4.0;
final int   CA_FLIGHT_MS        = 140;
final int   CA_JUMP_COOLDOWN_MS = 700;

final float CA_SIDE_THRESH      = 4.0;
final float CA_SIDE_DOMINANCE   = 1.3;
final int   CA_SIDE_COOLDOWN_MS = 450;

boolean caEnabled    = true;
boolean caCalibrated = false;

float[] caGrav = new float[3];
float[] caLin  = new float[3];
boolean caGravInit = false;
int   caUp = 1, caLat = 0, caFwd = 2;
float caLatSign = 1;

float caAccMag = 0, caGyroMag = 0, caLatNow = 0, caFwdNow = 0;
boolean caAirborne = false;
int   caFlightStart = -1;
boolean caJumpSent = false;
int   caLastJump = -10000, caLastSide = -10000;

int    caCalState = 0;
int    caCalStart = 0;
String caMsg = "Press C, stand still, then take one step to your LEFT.";

final String CA_AXES = "XYZ";

void caInitRobot() {
  if (robot != null) return;
  try {
    robot = new Robot();
    caMsg = "Robot ready. Click the game window so it has focus, then move.";
  } catch (Exception e) {
    caMsg = "Could not create the Robot: " + e.getMessage();
  }
}

synchronized void triggerAction(int i, String source) {
  if (robot == null || !caEnabled || screen != 2) return;
  if (held[i]) return;
  robot.keyPress(actionKeys[i]);
  held[i] = true;
  releaseAt[i] = millis() + KEY_HOLD_MS;
  lastEvent = source + " -> " + gestureActions[i] + " (" + actionKeyNames[i] + ")";
  lastEventMs = millis();
  println(lastEvent);
}

synchronized void releaseDue() {
  for (int i = 0; i < held.length; i++) {
    if (held[i] && millis() >= releaseAt[i]) {
      robot.keyRelease(actionKeys[i]);
      held[i] = false;
    }
  }
}

synchronized void caReleaseAll() {
  if (robot == null) return;
  for (int i = 0; i < held.length; i++) {
    if (held[i]) robot.keyRelease(actionKeys[i]);
    held[i] = false;
  }
}

void exit() {
  caReleaseAll();
  super.exit();
}

boolean caFootOff() {
  return mfBuf[BUF-1] < FOOT_OFF && lfBuf[BUF-1] < FOOT_OFF
      && mmBuf[BUF-1] < FOOT_OFF && heelBuf[BUF-1] < HEEL_OFF;
}

void caStartCalibration() {
  caCalState = 1;
  caCalStart = millis();
  caMsg = "Stand still for 1 s, then take one step to your LEFT...";
}

void coolFeed(float fx, float fy, float fz, float wx, float wy, float wz, int now) {
  float[] a = { fx, fy, fz };
  if (!caGravInit) { arrayCopy(a, 0, caGrav, 0, 3); caGravInit = true; }

  for (int i = 0; i < 3; i++) {
    caLin[i] = a[i] - caGrav[i];
    caGrav[i] += 0.02 * (a[i] - caGrav[i]);
  }

  caUp = 0;
  for (int i = 1; i < 3; i++) if (abs(caGrav[i]) > abs(caGrav[caUp])) caUp = i;
  if (!caCalibrated) {
    caLat = (caUp == 0) ? 1 : 0;
    caFwd = 3 - caUp - caLat;
  }

  caAccMag  = sqrt(fx * fx + fy * fy + fz * fz);
  caGyroMag = sqrt(wx * wx + wy * wy + wz * wz);

  if (caMode == MODE_RELAXED) { caRelaxedFeed(now); return; }
  if (caMode == MODE_SPACE && SPACE_FROM_PAD) caSpacePadFeed();

  caAirborne = caFootOff() && caAccMag < CA_FLIGHT_ACCEL_MAX && caGyroMag < CA_FLIGHT_GYRO_MAX;
  if (caAirborne) {
    if (caFlightStart < 0) caFlightStart = now;
    if (!caJumpSent && now - caFlightStart >= CA_FLIGHT_MS && now - caLastJump > CA_JUMP_COOLDOWN_MS) {
      if (caMode != MODE_SPACE)  triggerAction(0, "jump gesture");
      else if (SPACE_FROM_JUMP)  triggerAction(3, "jump gesture");
      caJumpSent = true;
      caLastJump = now;
    }
  } else {
    caFlightStart = -1;
    caJumpSent = false;
  }

  if (caMode == MODE_SPACE) return;
  caLatNow = caLin[caLat] * caLatSign;
  caFwdNow = caLin[caFwd];

  if (caCalState == 1) {
    if (now - caCalStart > 7000) {
      caCalState = 0;
      caMsg = "Calibration timed out. Press C to try again.";
    } else if (now - caCalStart > 1000) {
      int h0 = (caUp == 0) ? 1 : 0;
      int h1 = 3 - caUp - h0;
      int best = abs(caLin[h0]) >= abs(caLin[h1]) ? h0 : h1;
      if (abs(caLin[best]) > CA_SIDE_THRESH) {
        caLat = best;
        caFwd = 3 - caUp - best;
        caLatSign = caLin[best] > 0 ? 1 : -1;
        caCalibrated = true;
        caCalState = 0;
        caLastSide = now;
        caMsg = "Calibrated: LEFT = " + (caLatSign > 0 ? "+" : "-") + CA_AXES.charAt(caLat) + " axis.";
      }
    }
    return;
  }

  if (!caAirborne && now - caLastSide > CA_SIDE_COOLDOWN_MS) {
    float lat = caLatNow, fwd = caFwdNow;
    if (abs(lat) > CA_SIDE_THRESH && abs(lat) > CA_SIDE_DOMINANCE * abs(fwd)) {
      if (lat > 0) triggerAction(1, "side push");
      else         triggerAction(2, "side push");
      caLastSide = now;
    }
  }
}

final int CA_BTN_W = 210, CA_BTN_H = 54, CA_BTN_Y = 600;
final int[] CA_BTN_X = { 60, 320, 580, 840 };
final String[] CA_BTN_LABEL = { "Back (B)", "Calibrate (C)", "Controller (E)", "Mode (M)" };

boolean caHit(int i) {
  return mouseX >= CA_BTN_X[i] && mouseX <= CA_BTN_X[i] + CA_BTN_W
      && mouseY >= CA_BTN_Y && mouseY <= CA_BTN_Y + CA_BTN_H;
}

void drawCoolApp() {
  caInitRobot();
  releaseDue();
  background(240);

  fill(30); textAlign(CENTER, CENTER); textSize(26);
  text("Cool Application", width / 2, 50);
  fill(110); textSize(13);
  text("Click the game window first. Jump = W   |   step sideways = A / D", width / 2, 82);

  textAlign(LEFT, CENTER); textSize(15); fill(50);
  int x = 150;
  for (int i = 0; i < gestureActions.length; i++) {
    text("Action " + i + ": " + gestureActions[i] + " -> " + actionKeyNames[i] + (held[i] ? "  [held]" : ""), x, 120 + i * 22);
  }

  int y = 205, dy = 34;
  text("Mode:  " + CA_MODE_NAME[caMode] + "      Controller:  " + (caEnabled ? "ON" : "OFF (keys not sent)"), x, y);
    if (caMode == MODE_RELAXED) {
    text("Pads (press above " + int(RELAXED_ON) + "):  MF " + int(caPadValue[0]) + " (JUMP)   MM "
         + int(caPadValue[1]) + " (LEFT)   LF " + int(caPadValue[2]) + " (RIGHT)", x, y + dy);
    } else if (caMode == MODE_SPACE) {
      text("Space:  MF " + int(caPadValue[0]) + " (press above " + int(RELAXED_ON) + ")     Foot: "
           + (caAirborne ? "AIRBORNE" : "on ground"), x, y + dy);
    } else {
      text("Foot:  " + (caAirborne ? "AIRBORNE" : "on ground"), x, y + dy);
    }
  text("|accel|:  " + nf(caAccMag, 0, 1) + " m/s^2     (airborne below " + nf(CA_FLIGHT_ACCEL_MAX, 0, 1) + ")", x, y + 2 * dy);
  text("|gyro|:  " + nf(caGyroMag, 0, 2) + " rad/s     (airborne below " + nf(CA_FLIGHT_GYRO_MAX, 0, 1) + ")", x, y + 3 * dy);
  text("Axes:  up = " + CA_AXES.charAt(caUp) + ",  sideways = " + CA_AXES.charAt(caLat)
       + (caCalibrated ? "  (calibrated)" : "  (default, press C)"), x, y + 4 * dy);
  text("Sideways push:  " + nf(caLatNow, 0, 1) + " m/s^2     forward/back: " + nf(caFwdNow, 0, 1), x, y + 5 * dy);

  int bx = x, by = y + 6 * dy, bw = 500;
  noFill(); stroke(180); rect(bx, by, bw, 18);
  float t = bw / 2.0 * CA_SIDE_THRESH / 12.0;
  stroke(220, 120, 120);
  line(bx + bw / 2 - t, by, bx + bw / 2 - t, by + 18);
  line(bx + bw / 2 + t, by, bx + bw / 2 + t, by + 18);
  stroke(180); line(bx + bw / 2, by, bx + bw / 2, by + 18);
  noStroke(); fill(70, 120, 220);
  float len = constrain(caLatNow / 12.0, -1, 1) * bw / 2;
  if (len > 0) rect(bx + bw / 2 - len, by, len, 18);
  else         rect(bx + bw / 2, by, -len, 18);

  fill(50); textAlign(LEFT, CENTER);
  text("Last: " + lastEvent + (lastEventMs > 0 ? "  (" + nf((millis() - lastEventMs) / 1000.0, 0, 1) + " s ago)" : ""), x, by + 50);
  fill(70, 120, 220);
  text(caMsg, x, by + 84);

  for (int i = 0; i < CA_BTN_X.length; i++) {
    boolean hover = caHit(i);
    if (hover) { fill(200, 220, 255); stroke(70, 120, 220); } else { fill(255); stroke(180); }
    strokeWeight(1.5);
    rect(CA_BTN_X[i], CA_BTN_Y, CA_BTN_W, CA_BTN_H, 10);
    fill(hover ? 20 : 50); textAlign(CENTER, CENTER); textSize(15);
    text(CA_BTN_LABEL[i], CA_BTN_X[i] + CA_BTN_W / 2, CA_BTN_Y + CA_BTN_H / 2);
  }
  strokeWeight(1);
}

void caToggle() {
  caEnabled = !caEnabled;
  if (!caEnabled) caReleaseAll();
  caMsg = caEnabled ? "Controller on." : "Controller off. The keyboard (A / D / W) still works in the game window.";
}

void caBack() {
  caReleaseAll();
  screen = 0;
}

void coolClick() {
  if (caHit(0)) caBack();
  else if (caHit(1)) caStartCalibration();
  else if (caHit(2)) caToggle();
  else if (caHit(3)) caSetMode((caMode + 1) % 3);
}

void coolKey() {
  if (key == 'c' || key == 'C') caStartCalibration();
  else if (key == 'e' || key == 'E') caToggle();
  else if (key == 'b' || key == 'B') caBack();
  else if (key == 'm' || key == 'M') caSetMode((caMode + 1) % 3);
  else if (key == '1') caSetMode(MODE_STRENUOUS);
  else if (key == '2') caSetMode(MODE_RELAXED);
  else if (key == '3') caSetMode(MODE_SPACE);
  else if (key >= '7' && key <= '9') triggerAction(key - '7', "keyboard test");
  else if (key == '0') triggerAction(3, "keyboard test");
}

void caSetMode(int m) {
  caMode = m;
  caReleaseAll();
  caPadDown  = new boolean[3];
  caPadArmed = new boolean[3];
  caFlightStart = -1;
  caJumpSent = false;
  caLastJump = millis();
  caLastSide = millis();
  if (m == MODE_RELAXED)    caMsg = "Mode: Relaxed. Press the foot sensors: MF = jump, MM = left, LF = right.";
  else if (m == MODE_SPACE) caMsg = "Mode: Space only. An MF press or a jump sends Space.";
  else                      caMsg = "Mode: Strenuous. Jump to jump, step sideways to change lane.";
}

void caRelaxedFeed(int now) {
  float[] pad = { mfBuf[BUF-1], mmBuf[BUF-1], lfBuf[BUF-1] };
  for (int p = 0; p < 3; p++) {
    caPadValue[p] = pad[p];
    if (!caPadArmed[p]) {
      caPadArmed[p] = pad[p] < RELAXED_OFF;
      continue;
    }
    if (!caPadDown[p] && pad[p] > RELAXED_ON) {
      caPadDown[p] = true;
      triggerAction(RELAXED_PAD_ACTION[p], "pad " + RELAXED_PAD_NAME[p]);
    } else if (caPadDown[p] && pad[p] < RELAXED_OFF) {
      caPadDown[p] = false;
    }
  }
}

void caSpacePadFeed() {
  float mf = mfBuf[BUF-1];
  caPadValue[0] = mf;
  if (!caPadArmed[0]) { caPadArmed[0] = mf < RELAXED_OFF; return; }
  if (!caPadDown[0] && mf > RELAXED_ON) {
    caPadDown[0] = true;
    triggerAction(3, "pad MF");
  } else if (caPadDown[0] && mf < RELAXED_OFF) {
    caPadDown[0] = false;
  }
}
