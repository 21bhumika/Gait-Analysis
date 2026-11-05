import java.util.concurrent.CopyOnWriteArrayList;

final int   JUMP_HOLD_STILL_MS  = 1500;
final int   JUMP_PROMPT_MS      = 5000;
final int   JUMP_RESULT_MS      = 3000;
final int   JUMP_MIN_FLIGHT_MS  = 120;
final int   JUMP_MAX_FLIGHT_MS  = 1000;
final int   JUMP_LAND_WINDOW_MS = 200;
final float JUMP_MIN_IMPACT     = 14;
final int   JUMP_LIST_SIZE      = 5;
final int   JUMP_PUSH_WINDOW_MS = 150;
final int   JUMP_SAME_TIME_MS   = 30;

final int J_STILL = 0, J_PROMPT = 1, J_AIR = 2, J_LANDING = 3, J_RESULT = 4;

class JumpResult {
  float heightCm, flightS;
  String takeoffStance, landingStance;

  JumpResult(float flightS, String takeoffStance, String landingStance) {
    this.flightS = flightS;
    this.takeoffStance = takeoffStance;
    this.landingStance = landingStance;
    heightCm = 100 * GRAVITY * flightS * flightS / 8;
  }
}

CopyOnWriteArrayList<JumpResult> jumps = new CopyOnWriteArrayList<JumpResult>();

int jState = J_STILL;
int jStateT = 0;
int jStillSince = -1;
int jLastT = -1;
float jTakeoffT = 0, jTouchT = 0;
float jLandPeak = 0;
String jMessage = "";
float[] jPrev = new float[4];
String jTakeoffStance = "";
float[] jFirstTouch = new float[4];

float jumpBest() {
  float best = 0;
  for (JumpResult j : jumps) best = max(best, j.heightCm);
  return best;
}

void jGoTo(int state, int t) {
  jState = state;
  jStateT = t;
  jStillSince = -1;
}

void jReject(String why, int t) {
  jMessage = why;
  jGoTo(J_RESULT, t);
}

float jLiftTime(float[] now, int t, float dtMs) {
  float[] limit = {FOOT_OFF, FOOT_OFF, FOOT_OFF, HEEL_OFF};
  float latest = t - dtMs;
  for (int s = 0; s < 4; s++) {
    if (jPrev[s] < limit[s]) continue;
    latest = max(latest, t - dtMs + dtMs * (jPrev[s] - limit[s]) / max(jPrev[s] - now[s], 1));
  }
  return latest;
}

float jTouchTime(float[] now, int t, float dtMs) {
  float[] limit = {FOOT_ON, FOOT_ON, FOOT_ON, HEEL_ON};
  float earliest = t;
  for (int s = 0; s < 4; s++) {
    if (now[s] <= limit[s]) continue;
    earliest = min(earliest, t - dtMs + dtMs * (limit[s] - jPrev[s]) / max(now[s] - jPrev[s], 1));
  }
  return earliest;
}

String takeoffStance() {
  int samples = max(1, JUMP_PUSH_WINDOW_MS * SAMPLE_HZ / 1000);
  boolean fore = false, heel = false;
  for (int k = 1; k <= samples; k++) {
    int i = BUF - 1 - k;
    fore = fore || mfBuf[i] > FOOT_ON || lfBuf[i] > FOOT_ON || mmBuf[i] > FOOT_ON;
    heel = heel || heelBuf[i] > HEEL_ON;
  }
  return fore && heel ? "Flat foot" : fore ? "Forefoot" : heel ? "Heel" : "Light";
}

void noteTouches(float[] now, int t, float dtMs) {
  float[] limit = {FOOT_ON, FOOT_ON, FOOT_ON, HEEL_ON};
  for (int s = 0; s < 4; s++) {
    if (jFirstTouch[s] >= 0 || now[s] <= limit[s]) continue;
    jFirstTouch[s] = t - dtMs + dtMs * (limit[s] - jPrev[s]) / max(now[s] - jPrev[s], 1);
  }
}

String landingStance() {
  float fore = -1;
  for (int s = 0; s < 3; s++) {
    if (jFirstTouch[s] >= 0 && (fore < 0 || jFirstTouch[s] < fore)) fore = jFirstTouch[s];
  }
  float heel = jFirstTouch[3];
  if (fore < 0) return "Heel first";
  if (heel < 0) return "Forefoot first";
  if (abs(heel - fore) <= JUMP_SAME_TIME_MS) return "Flat foot";
  return heel < fore ? "Heel first" : "Forefoot first";
}

synchronized void jumpFeed(float fx, float fy, float fz, float wx, float wy, float wz, int t) {
  if (screen != 4) return;

  float[] now = {mfBuf[BUF-1], lfBuf[BUF-1], mmBuf[BUF-1], heelBuf[BUF-1]};
  float dtMs = t - jLastT;
  boolean firstOrGap = jLastT < 0 || dtMs <= 0 || dtMs > 200;
  jLastT = t;

  if (firstOrGap) {
    jMessage = "";
    jGoTo(J_STILL, t);
    jPrev = now;
    return;
  }

  boolean off = now[0] < FOOT_OFF && now[1] < FOOT_OFF && now[2] < FOOT_OFF && now[3] < HEEL_OFF;
  boolean on  = now[0] > FOOT_ON  || now[1] > FOOT_ON  || now[2] > FOOT_ON  || now[3] > HEEL_ON;
  float acc = sqrt(fx * fx + fy * fy + fz * fz);
  float rate = sqrt(wx * wx + wy * wy + wz * wz);

  if (jState == J_STILL) {
    boolean still = on && rate < STILL_GYRO && abs(acc - GRAVITY) < STILL_ACCEL;
    if (!still) jStillSince = -1;
    else if (jStillSince < 0) jStillSince = t;
    else if (t - jStillSince >= JUMP_HOLD_STILL_MS) {
      jMessage = "";
      jGoTo(J_PROMPT, t);
    }
  } else if (jState == J_PROMPT) {
    if (off) {
      jTakeoffT = jLiftTime(now, t, dtMs);
      jTakeoffStance = takeoffStance();
      jGoTo(J_AIR, t);
    } else if (t - jStateT > JUMP_PROMPT_MS) {
      jMessage = "No jump seen";
      jGoTo(J_STILL, t);
    }
  } else if (jState == J_AIR) {
    if (on) {
      jTouchT = jTouchTime(now, t, dtMs);
      jFirstTouch = new float[] {-1, -1, -1, -1};
      noteTouches(now, t, dtMs);
      jLandPeak = acc;
      jGoTo(J_LANDING, t);
    } else if (t - jTakeoffT > JUMP_MAX_FLIGHT_MS) {
      jReject("Foot was off the ground too long", t);
    }
  } else if (jState == J_LANDING) {
    jLandPeak = max(jLandPeak, acc);
    noteTouches(now, t, dtMs);
    if (t - jStateT >= JUMP_LAND_WINDOW_MS) finishJump(t);
  } else if (jState == J_RESULT) {
    if (t - jStateT >= JUMP_RESULT_MS) jGoTo(J_STILL, t);
  }
  jPrev = now;
}

void finishJump(int t) {
  float flightMs = jTouchT - jTakeoffT;
  if (flightMs < JUMP_MIN_FLIGHT_MS || jLandPeak < JUMP_MIN_IMPACT) {
    jReject("That didn't look like a jump", t);
    return;
  }
  jMessage = "";
  jumps.add(new JumpResult(flightMs / 1000, jTakeoffStance, landingStance()));
  jGoTo(J_RESULT, t);
}

final int J_CLEAR_X = 862, J_CLEAR_Y = 34, J_CLEAR_W = 78, J_CLEAR_H = 30;

void drawJumpAnalysis() {
  pageTitle("Jump", "");
  pillButton("Clear", J_CLEAR_X, J_CLEAR_Y, J_CLEAR_W, J_CLEAR_H, C_SECOND, false);
  drawRecordBtn();

  drawJumpPrompt(CX, 86, CW, 180);

  JumpResult last = jumps.isEmpty() ? null : jumps.get(jumps.size() - 1);

  int cy = 282, ch = 396, lw = 520;
  card(CX, cy, lw, ch);
  cardHeader(CX, cy, lw, "jump", "Last Jump", C_PINK, last == null ? "" : nf(last.flightS, 0, 2) + " s in the air", false);

  String height = last == null ? "—" : str(round(anim("jumpHeight", last.heightCm)));
  textFont(fontB, 110);
  metric(height, last == null ? "" : "cm", CX + 22, cy + 170, 110, lw - 44);

  stroke(C_SEP); strokeWeight(1);
  line(CX + 22, cy + 222, CX + lw - 22, cy + 222);
  drawJumpStance("Takeoff Stance", last == null ? "—" : last.takeoffStance, CX + 22, cy + 240);
  drawJumpStance("Landing Stance", last == null ? "—" : last.landingStance, CX + lw / 2 + 11, cy + 240);

  int rx = CX + lw + 16, rw = CW - lw - 16;
  card(rx, cy, rw, ch);
  cardHeader(rx, cy, rw, "jump", "Best", C_ORANGE, "", false);
  metric(jumps.isEmpty() ? "—" : str(round(jumpBest())), jumps.isEmpty() ? "" : "cm", rx + 16, cy + 92, 52, rw - 32);

  stroke(C_SEP); strokeWeight(1);
  line(rx + 16, cy + 116, rx + rw - 16, cy + 116);
  tx(14, true, C_LABEL, LEFT, TOP);
  text("Recent", rx + 16, cy + 128);

  int n = jumps.size();
  if (n == 0) {
    tx(14, false, C_SECOND, LEFT, TOP);
    text("Your jumps will appear here", rx + 16, cy + 158);
  }
  float top = max(jumpBest(), 1);
  for (int k = 0; k < min(n, JUMP_LIST_SIZE); k++) {
    JumpResult j = jumps.get(n - 1 - k);
    int y = cy + 156 + k * 44;
    tx(16, true, C_LABEL, LEFT, TOP);
    text(round(j.heightCm) + " cm", rx + 16, y);
    tx(12, false, C_SECOND, RIGHT, TOP);
    text(nf(j.flightS, 0, 2) + " s", rx + rw - 16, y + 3);
    noStroke();
    fill(C_SEP);
    rect(rx + 16, y + 24, rw - 32, 6, 3);
    fill(C_PINK);
    rect(rx + 16, y + 24, (rw - 32) * j.heightCm / top, 6, 3);
  }
}

void drawJumpStance(String label, String value, int x, int y) {
  tx(13, false, C_SECOND, LEFT, TOP);
  text(label, x, y);
  metric(value, "", x, y + 70, 30, 236);
}

void drawJumpPrompt(int x, int y, int w, int h) {
  String title, sub = "";
  color bg;

  if (!insoleConnected()) {
    title = "Waiting for insole";
    sub = "Check the insole is connected";
    bg = C_SECOND;
  } else if (jState == J_STILL) {
    title = "Stand still";
    sub = jMessage.length() > 0 ? jMessage + ". Feet flat, stand still to try again"
                                : "Stand on both feet and wait for the signal";
    bg = C_ORANGE;
  } else if (jState == J_PROMPT) {
    title = "Jump!";
    sub = "Jump straight up and land on both feet";
    bg = C_GREEN;
  } else if (jState == J_AIR || jState == J_LANDING) {
    title = "In the air...";
    bg = C_BLUE;
  } else if (jMessage.length() > 0) {
    title = "Try again";
    sub = jMessage;
    bg = C_RED;
  } else {
    title = "Nice jump!";
    sub = "Get ready for the next one";
    bg = C_BLUE;
  }

  noStroke();
  fill(bg);
  rect(x, y, w, h, 18);

  tx(72, true, color(255), CENTER, CENTER);
  text(title, x + w / 2, y + h / 2 - 26);
  tx(20, false, color(255), CENTER, CENTER);
  text(sub, x + w / 2, y + h - 44);

  if (jState == J_STILL && jStillSince >= 0 && insoleConnected()) {
    float progress = constrain((jLastT - jStillSince) / float(JUMP_HOLD_STILL_MS), 0, 1);
    fill(255, 90);
    rect(x + 30, y + h - 20, w - 60, 8, 4);
    fill(255);
    rect(x + 30, y + h - 20, (w - 60) * progress, 8, 4);
  }
}

void jumpClick() {
  if (recordBtnHit()) {
    toggleRecording();
  } else if (mouseOver(J_CLEAR_X, J_CLEAR_Y, J_CLEAR_W, J_CLEAR_H)) {
    jumps.clear();
  }
}
