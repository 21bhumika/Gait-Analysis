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

final char[] GAME_KEYS = {'w', 'a', 'd', 'w'};
boolean[] robotHeld = new boolean[gestureActions.length];
boolean[] held      = new boolean[gestureActions.length];
int[]     releaseAt = new int[gestureActions.length];
final int KEY_HOLD_MS = 80;

Robot robot;
String lastEvent = "waiting for input...";
int lastEventMs = 0;

final float CA_UNLOADED = 0.40, CA_RELOADED = 0.55;
final float CA_FIRST_UNLOADED = 0.60, CA_FIRST_RELOADED = 0.72;   // until an in-air level is known
final int   CA_STAND_STILL_MS = 500;
final int   CA_READY_STILL_MS = 300;    // a lifted foot looks the same in a step and a jump,
final int   CA_READY_WINDOW_MS = 1200;  // so a jump has to start from standing still
final int   CA_FLIGHT_MS        = 100;
final int   CA_JUMP_COOLDOWN_MS = 700;
final int   CA_JUMP_AFTER_SIDE_MS = 400;

int caStillSince = -1;
int caLastReadyAt = -100000;
float caStandLoad = 0;
float caAirLoad = -1;
float caAirMin = 0;
float caLoadShare = 1;
boolean caFootUp = false;

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
String caMsg = "Calibrate once, then jump and step sideways to play.";

final String CA_AXES = "XYZ";

void caInitRobot() {
  if (robot != null) return;
  try {
    robot = new Robot();
  } catch (Exception e) {
    caMsg = "Could not create the Robot: " + e.getMessage();
  }
}

synchronized void triggerAction(int i, String source) {
  if (!caEnabled || screen != 2) return;
  if (held[i]) return;
  if (gameRunning()) {
    sendGameKey(GAME_KEYS[i]);
  } else {
    if (robot == null) return;
    robot.keyPress(actionKeys[i]);
    robotHeld[i] = true;
  }
  held[i] = true;
  releaseAt[i] = millis() + KEY_HOLD_MS;
  lastEvent = source + " -> " + gestureActions[i] + " (" + actionKeyNames[i] + ")";
  lastEventMs = millis();
  println(lastEvent);
}

synchronized void releaseDue() {
  for (int i = 0; i < held.length; i++) {
    if (held[i] && millis() >= releaseAt[i]) {
      if (robotHeld[i]) robot.keyRelease(actionKeys[i]);
      robotHeld[i] = false;
      held[i] = false;
    }
  }
}

synchronized void caReleaseAll() {
  if (robot == null) return;
  for (int i = 0; i < held.length; i++) {
    if (robotHeld[i]) robot.keyRelease(actionKeys[i]);
    robotHeld[i] = false;
    held[i] = false;
  }
}

void exit() {
  caReleaseAll();
  super.exit();
}

// A shoe keeps some pressure on the sensors even in the air, so this compares total
// pressure with this wearer's own standing and in-air levels instead of fixed limits.
void caUpdateFootLoad(int now) {
  float load = mfBuf[BUF-1] + lfBuf[BUF-1] + mmBuf[BUF-1] + heelBuf[BUF-1];

  boolean still = caGyroMag < STILL_GYRO && abs(caAccMag - GRAVITY) < STILL_ACCEL;
  if (!still) caStillSince = -1;
  else if (caStillSince < 0) caStillSince = now;
  if (still && now - caStillSince >= CA_READY_STILL_MS) caLastReadyAt = now;
  if (still && now - caStillSince >= CA_STAND_STILL_MS) {
    caStandLoad = caStandLoad == 0 ? load : caStandLoad + 0.05 * (load - caStandLoad);
  }

  float floor = max(caAirLoad, 0);
  float range = caStandLoad - floor;
  if (range < 100) {
    caFootUp = false;
    caLoadShare = 1;
    return;
  }
  caLoadShare = (load - floor) / range;

  boolean learned = caAirLoad >= 0;
  if (!caFootUp && caLoadShare < (learned ? CA_UNLOADED : CA_FIRST_UNLOADED)) {
    caFootUp = true;
    caAirMin = load;
  } else if (caFootUp) {
    caAirMin = min(caAirMin, load);
    if (caLoadShare > (learned ? CA_RELOADED : CA_FIRST_RELOADED)) {
      caFootUp = false;
      caAirLoad = caAirLoad < 0 ? caAirMin : 0.7 * caAirLoad + 0.3 * caAirMin;
    }
  }
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

  caUpdateFootLoad(now);
  caAirborne = caFootUp;
  if (caAirborne) {
    if (caFlightStart < 0) caFlightStart = now;
    if (!caJumpSent && now - caFlightStart >= CA_FLIGHT_MS && now - caLastJump > CA_JUMP_COOLDOWN_MS
        && now - caLastSide > CA_JUMP_AFTER_SIDE_MS && now - caLastReadyAt < CA_READY_WINDOW_MS) {
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

final String[] CA_MODE_SHORT = {"Strenuous", "Relaxed", "Space Only"};
final int CA_LX = 234, CA_LW = 413, CA_RX = 663, CA_RW = 413;
final int CA_SWITCH_X = 581, CA_SWITCH_Y = 128;
final int CA_MODE_X = 248, CA_MODE_Y = 216, CA_MODE_W = 385, CA_MODE_H = 32;
final int CA_CAL_X = 248, CA_CAL_Y = 264, CA_CAL_W = 385, CA_CAL_H = 36;

final String[] GAME_TABS = {"Play", "Controller"};
final int GT_TAB_X = 856, GT_TAB_Y = 34, GT_TAB_W = 220, GT_TAB_H = 32;
final int GV_Y = 80, GV_H = 561;

void drawCoolApp() {
  caInitRobot();
  releaseDue();

  pageTitle("Game", "");
  segmented(GT_TAB_X, GT_TAB_Y, GT_TAB_W, GT_TAB_H, GAME_TABS, gamePlayTab, "gameTab");

  if (gamePlayTab == 0) drawGamePlay();
  else drawGameController();
}

void drawGamePlay() {
  drawGameView(CX, GV_Y, CW, GV_H);

  int y = GV_Y + GV_H + 10;
  noStroke();
  fill(caAirborne ? C_BLUE : C_GREEN);
  ellipse(CX + 7, y + 13, 10, 10);
  tx(13, true, C_LABEL, LEFT, CENTER);
  text(caAirborne ? "Airborne" : "On ground", CX + 20, y + 12);
  tx(13, false, C_SECOND, LEFT, CENTER);
  text(CA_MODE_SHORT[caMode] + (caEnabled ? "" : "   Controller off"), CX + 110, y + 12);

  int size = 28, gap = 6;
  for (int i = 0; i < 3; i++) {
    int x = CX + CW - (3 - i) * (size + gap) + gap;
    float glow = anim("caHeld" + i, held[i] ? 1 : 0);
    noStroke();
    fill(lerpColor(C_FILL, C_BLUE, glow));
    rect(x, y, size, size, 7);
    tx(13, true, lerpColor(C_LABEL, color(255), glow), CENTER, CENTER);
    text(actionKeyNames[i], x + size / 2, y + size / 2 - 1);
  }
}

void drawGameController() {
  card(CA_LX, 86, CA_LW, 330);
  cardHeader(CA_LX, 86, CA_LW, "game", "Controller", C_INDIGO, "", false);

  tx(16, true, C_LABEL, LEFT, TOP);
  text("Foot control", CA_LX + 14, 124);
  tx(13, false, C_SECOND, LEFT, TOP);
  text(caEnabled ? "On. Your foot controls the game" : "Off. Your foot does nothing", CA_LX + 14, 146);
  toggleSwitch(CA_SWITCH_X, CA_SWITCH_Y, caEnabled, "caSwitch");

  stroke(C_SEP); strokeWeight(1);
  line(CA_LX + 14, 176, CA_LX + CA_LW - 14, 176);

  tx(14, true, C_LABEL, LEFT, TOP);
  text("Control Mode", CA_MODE_X, 190);
  segmented(CA_MODE_X, CA_MODE_Y, CA_MODE_W, CA_MODE_H, CA_MODE_SHORT, caMode, "caMode");

  pillButton(caCalState == 1 ? "Calibrating..." : "Calibrate Sideways Step", CA_CAL_X, CA_CAL_Y, CA_CAL_W, CA_CAL_H, C_INDIGO, false);

  tx(13, false, C_SECOND, LEFT, TOP);
  textLeading(18);
  text(caMsg, CA_LX + 14, 314, CA_LW - 28, 60);
  tx(12, false, C_SECOND, LEFT, BOTTOM);
  text("Keys: M mode   C calibrate   E controller   B back", CA_LX + 14, 408);

  card(CA_RX, 86, CA_RW, 330);
  cardHeader(CA_RX, 86, CA_RW, "heart", "Live", C_PINK, "", false);

  if (caMode == MODE_RELAXED) {
    caPadRow("MF", "Jump", caPadValue[0], 126);
    caPadRow("MM", "Left", caPadValue[1], 180);
    caPadRow("LF", "Right", caPadValue[2], 234);
  } else {
    tx(13, false, C_SECOND, LEFT, TOP);
    text("Foot", CA_RX + 14, 124);
    textAlign(RIGHT, TOP);
    text(caStandLoad == 0 ? "Stand still to set your level"
         : "Pressure " + round(100 * constrain(caLoadShare, 0, 2)) + "% of standing", CA_RX + CA_RW - 14, 124);
    metric(caAirborne ? "Airborne" : "On Ground", "", CA_RX + 14, 174, 30, 200);
    if (caMode == MODE_SPACE) {
      caPadRow("MF", "Space", caPadValue[0], 200);
    } else {
      caStat("Accel", nf(caAccMag, 0, 1), "m/s²", CA_RX + 14, 196);
      caStat("Gyro", nf(caGyroMag, 0, 2), "rad/s", CA_RX + 210, 196);
    }
  }

  if (caMode == MODE_STRENUOUS) {
    tx(13, false, C_SECOND, LEFT, TOP);
    text("Sideways push", CA_RX + 14, 276);
    drawSideBar(CA_RX + 14, 298, CA_RW - 28, 12);
    tx(11, false, C_SECOND, LEFT, TOP);
    text("Left", CA_RX + 14, 316);
    textAlign(RIGHT, TOP);
    text("Right", CA_RX + CA_RW - 14, 316);
  }

  tx(13, false, C_SECOND, LEFT, TOP);
  text(caCalibrated ? "Calibrated, sideways is " + CA_AXES.charAt(caLat) : "Not calibrated", CA_RX + 14, 382);

  card(CA_LX, 432, CW, 246);
  cardHeader(CA_LX, 432, CW, "cadence", "Actions", C_BLUE, lastEventMs > 0 ? nf((millis() - lastEventMs) / 1000.0, 0, 1) + " s ago" : "", false);

  int tileW = (CW - 28 - 36) / 4;
  for (int i = 0; i < gestureActions.length; i++) {
    int x = CA_LX + 14 + i * (tileW + 12);
    float glow = anim("caHeld" + i, held[i] ? 1 : 0);
    noStroke();
    fill(lerpColor(C_BG, C_BLUE, glow));
    rect(x, 476, tileW, 110, 12);
    tx(36, true, lerpColor(C_LABEL, color(255), glow), CENTER, CENTER);
    text(actionKeyNames[i], x + tileW / 2, 516);
    tx(12, false, lerpColor(C_SECOND, color(255), glow), CENTER, CENTER);
    text(CA_ACTION_NAME[i], x + tileW / 2, 560);
  }
  tx(13, false, C_SECOND, LEFT, TOP);
  text("Last: " + lastEvent, CA_LX + 14, 606);
  tx(12, false, C_SECOND, LEFT, TOP);
  text("Keyboard: W jump, A left, D right, or 7, 8, 9 and 0 to test the actions.", CA_LX + 14, 630);
}

final String[] CA_ACTION_NAME = {"Jump", "Move Left", "Move Right", "Space"};

void caStat(String label, String value, String unit, int x, int y) {
  tx(13, false, C_SECOND, LEFT, TOP);
  text(label, x, y);
  metric(value, unit, x, y + 50, 28, 180);
}

void caPadRow(String name, String action, float value, int y) {
  tx(14, true, C_LABEL, LEFT, TOP);
  text(name, CA_RX + 14, y);
  tx(13, false, C_SECOND, LEFT, TOP);
  text(action, CA_RX + 54, y + 1);
  tx(13, true, C_LABEL, RIGHT, TOP);
  text(int(value), CA_RX + CA_RW - 14, y);
  noStroke();
  fill(C_SEP);
  rect(CA_RX + 14, y + 24, CA_RW - 28, 10, 5);
  fill(value > RELAXED_ON ? C_GREEN : C_BLUE);
  rect(CA_RX + 14, y + 24, (CA_RW - 28) * constrain(value, 0, 1023) / 1023, 10, 5);
}

void drawSideBar(int x, int y, int w, int h) {
  noStroke();
  fill(C_SEP);
  rect(x, y, w, h, h / 2.0);
  float limit = w / 2.0 * CA_SIDE_THRESH / 12.0;
  fill(C_SECOND);
  rect(x + w / 2 - limit, y - 2, 1.5, h + 4);
  rect(x + w / 2 + limit, y - 2, 1.5, h + 4);
  rect(x + w / 2, y - 2, 1.5, h + 4);
  fill(C_BLUE);
  float len = constrain(caLatNow / 12.0, -1, 1) * w / 2;
  if (len > 0) rect(x + w / 2 - len, y, len, h, h / 2.0);
  else if (len < 0) rect(x + w / 2, y, -len, h, h / 2.0);
}

void caToggle() {
  caEnabled = !caEnabled;
  if (!caEnabled) caReleaseAll();
  caMsg = caEnabled ? "Controller on." : "Controller off. The keyboard (A / D / W) still works in the game window.";
}

void caBack() {
  goTo(0);
}

void coolClick() {
  int tab = segmentHit(GT_TAB_X, GT_TAB_Y, GT_TAB_W, GT_TAB_H, GAME_TABS.length);
  if (tab >= 0) {
    gamePlayTab = tab;
    return;
  }
  if (gamePlayTab == 0) return;
  if (mouseOver(CA_SWITCH_X, CA_SWITCH_Y, 50, 30)) {
    caToggle();
    return;
  }
  int mode = segmentHit(CA_MODE_X, CA_MODE_Y, CA_MODE_W, CA_MODE_H, 3);
  if (mode >= 0) caSetMode(mode);
  else if (mouseOver(CA_CAL_X, CA_CAL_Y, CA_CAL_W, CA_CAL_H)) caStartCalibration();
}

void coolKey() {
  if ("wWaAdD ".indexOf(key) >= 0 && gameRunning()) sendGameKey(key == ' ' ? 'w' : key);
  else if (key == 'c' || key == 'C') caStartCalibration();
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
