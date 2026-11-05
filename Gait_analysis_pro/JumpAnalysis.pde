/*
 * JUMP ANALYSIS
 *   Vertical:   flight time from the pressure sensors (all unloaded) -> height = g*t^2/8, takeoff speed = g*t/2
 *   Horizontal: horizontal takeoff speed from integrating the push-off (stillness -> liftoff) x flight time.
 *               Below JUMP_HORIZ_MIN_M it is reported as 0.
 *   Stance:     pressure pattern in the 250 ms before liftoff (takeoff) and the first 150 ms after
 *               touchdown (landing), plus which sensor touches first.
 * Use: stand still for ~1 s, jump, land on both feet, stay still.
 */

import java.util.concurrent.CopyOnWriteArrayList;

// ---------- tunables ----------
final int   JUMP_MIN_FLIGHT_MS  = 120;   // foot unloaded at least this long = a jump (walking swings were < ~65 ms)
final int   JUMP_MAX_FLIGHT_MS  = 1200;  // longer than this = the foot was just lifted
final int   JUMP_PRE_WINDOW_MS  = 250;   // takeoff stance window before liftoff
final int   JUMP_LAND_WINDOW_MS = 150;   // landing stance window after touchdown
final float JUMP_MIN_IMPACT     = 14;    // m/s^2 peak accel at landing (rejects gentle foot lifts)
final float JUMP_HORIZ_MIN_M    = 0.10;  // below this the horizontal distance is reported as 0
final float JUMP_BALANCE        = 0.20;  // medial/lateral bias threshold
final int   JUMP_MAX_KEEP       = 12;
final int   JN = 128;                    // recent-sample ring (about 2.5 s at 50 Hz)

class JumpResult {
  int n, flightMs, pushMs;
  float heightCm, v0, speed, horizM, impactG;
  boolean horizOK;
  String takeoffLabel, landLabel;
  float[] takeoffPads, landPads;     // MF, LF, MM, HEEL peaks for the heatmaps
}

CopyOnWriteArrayList<JumpResult> jumps = new CopyOnWriteArrayList<JumpResult>();
int jumpCount = 0;

// ---------- state ----------
int jState = 0;                 // 0 on the ground, 1 foot off the ground, 2 capturing the landing
int jOffT = 0, jTouchT = 0, jLastT = -1;
float[] jPrePeaks = new float[4];
float[] jTakeVel = new float[3];
boolean jTakeValid = false;
int jPushMs = 0;
String jNote = "Stand still for a second, then jump.";

float[] jQ = null;              // foot orientation, null until the foot has been still
float[] jVel = new float[3];
float[] jStillAcc = new float[3];
float[] jLastGyro = new float[3];
int jStillCount = 0, jLastStillT = -1;

// ring of recent samples
int[]     jrT = new int[JN];
float[][] jrP = new float[JN][4];   // MF, LF, MM, HEEL
float[]   jrA = new float[JN];      // |accel|
int jrHead = 0, jrCount = 0;

void jrPush(int t, float mf, float lf, float mm, float heel, float acc) {
  jrT[jrHead] = t;
  jrP[jrHead][0] = mf; jrP[jrHead][1] = lf; jrP[jrHead][2] = mm; jrP[jrHead][3] = heel;
  jrA[jrHead] = acc;
  jrHead = (jrHead + 1) % JN;
  jrCount = min(jrCount + 1, JN);
}

int jrIdx(int k) { return (jrHead - 1 - k + 2 * JN) % JN; }   // k = 0 is the newest sample

float[] jrPeaks(int tFrom, int tTo) {
  float[] p = new float[4];
  for (int k = 0; k < jrCount; k++) {
    int i = jrIdx(k);
    if (jrT[i] < tFrom) break;
    if (jrT[i] > tTo) continue;
    for (int s = 0; s < 4; s++) p[s] = max(p[s], jrP[i][s]);
  }
  return p;
}

float jrPeakAccel(int tFrom, int tTo) {
  float peak = 0;
  for (int k = 0; k < jrCount; k++) {
    int i = jrIdx(k);
    if (jrT[i] < tFrom) break;
    if (jrT[i] > tTo) continue;
    peak = max(peak, jrA[i]);
  }
  return peak;
}

// ---------- called for every serial sample (needs the gyro fields) ----------
synchronized void jumpFeed(float fx, float fy, float fz, float wx, float wy, float wz, int t) {
  float acc = sqrt(fx * fx + fy * fy + fz * fz);
  float mf = mfBuf[BUF-1], lf = lfBuf[BUF-1], mm = mmBuf[BUF-1], heel = heelBuf[BUF-1];
  jrPush(t, mf, lf, mm, heel, acc);
  boolean off = mf < FOOT_OFF && lf < FOOT_OFF && mm < FOOT_OFF && heel < HEEL_OFF;

  float dt = jLastT < 0 ? 0 : (t - jLastT) / 1000.0;
  boolean gap = jLastT < 0 || dt <= 0 || dt > 0.2;
  jLastT = t;

  if (gap) {                              // first sample, or the stream stalled
    jResetReference();
    jState = 0;
    jLastGyro = new float[] {wx, wy, wz};
    return;
  }

  if (jState == 0) {
    jGround(fx, fy, fz, wx, wy, wz, dt, t, acc);
    if (off) jTakeoff(t);
  } else if (jState == 1) {
    if (!off) jTouchdown(t);
    else if (t - jOffT > JUMP_MAX_FLIGHT_MS) {
      jState = 0;
      jNote = "Ignored: foot off the ground for more than " + JUMP_MAX_FLIGHT_MS + " ms.";
      jResetReference();
    }
  } else if (jState == 2) {
    if (t - jTouchT >= JUMP_LAND_WINDOW_MS) jFinish();
  }
  jLastGyro = new float[] {wx, wy, wz};
}

void jResetReference() {
  jQ = null;
  jStillCount = 0;
  jLastStillT = -1;
  jVel = new float[3];
}

// On the ground: while still, set the orientation reference; otherwise integrate the push-off
void jGround(float fx, float fy, float fz, float wx, float wy, float wz, float dt, int t, float acc) {
  float rate = sqrt(wx * wx + wy * wy + wz * wz);
  jStillCount = (rate < STILL_GYRO && abs(acc - GRAVITY) < STILL_ACCEL) ? jStillCount + 1 : 0;

  if (jStillCount >= STILL_SAMPLES) {
    if (jStillCount == STILL_SAMPLES) jStillAcc = new float[3];
    jStillAcc[0] += fx; jStillAcc[1] += fy; jStillAcc[2] += fz;
    jQ = levelQuaternion(jStillAcc);
    jVel = new float[3];
    jLastStillT = t;
  } else if (jQ != null) {
    float mx = (wx + jLastGyro[0]) / 2, my = (wy + jLastGyro[1]) / 2, mz = (wz + jLastGyro[2]) / 2;
    float r2 = sqrt(mx * mx + my * my + mz * mz);
    if (r2 > 0) {
      float half = r2 * dt / 2;
      float s = sin(half) / r2;
      jQ = normalizedQ(multiplyQ(jQ, new float[] {cos(half), mx * s, my * s, mz * s}));
    }
    float[] world = rotateByQ(jQ, fx, fy, fz);
    world[2] -= GRAVITY;
    for (int i = 0; i < 3; i++) jVel[i] += world[i] * dt;
  }
}

void jTakeoff(int t) {
  float[] pre = jrPeaks(t - JUMP_PRE_WINDOW_MS, t);
  boolean wasLoaded = pre[0] > FOOT_ON || pre[1] > FOOT_ON || pre[2] > FOOT_ON || pre[3] > HEEL_ON;
  if (!wasLoaded) return;                 // foot was not on the ground, so this is not a takeoff

  jState = 1;
  jOffT = t;
  jPrePeaks = pre;
  jTakeValid = jQ != null && jLastStillT >= 0 && t - jLastStillT <= 2000;
  jTakeVel = new float[] {jVel[0], jVel[1], jVel[2]};
  jPushMs = jTakeValid ? t - jLastStillT : 0;
}

void jTouchdown(int t) {
  int flight = t - jOffT;
  if (flight < JUMP_MIN_FLIGHT_MS) {
    jNote = "Ignored: flight " + flight + " ms (needs " + JUMP_MIN_FLIGHT_MS + ").";
    jState = 0;
    jResetReference();
    return;
  }
  jTouchT = t;
  jState = 2;
}

void jFinish() {
  jState = 0;
  int flightMs = jTouchT - jOffT;
  float peakAcc = jrPeakAccel(jTouchT - 40, jTouchT + JUMP_LAND_WINDOW_MS);
  if (peakAcc < JUMP_MIN_IMPACT) {
    jNote = "Ignored: landing impact only " + nf(peakAcc / GRAVITY, 0, 1) + " g (foot lift?).";
    jResetReference();
    return;
  }

  JumpResult r = new JumpResult();
  r.n = ++jumpCount;
  r.flightMs = flightMs;
  float tf = flightMs / 1000.0;
  r.heightCm = 100 * GRAVITY * tf * tf / 8;
  r.v0 = GRAVITY * tf / 2;

  float vh = sqrt(jTakeVel[0] * jTakeVel[0] + jTakeVel[1] * jTakeVel[1]);
  float vz = jTakeVel[2];
  float dist = jTakeValid ? vh * tf : 0;
  r.horizOK = jTakeValid && vz > 0.5 * r.v0 && vz < 1.6 * r.v0;   // vertical speed from the push-off should match g*t/2
  r.horizM = dist < JUMP_HORIZ_MIN_M ? 0 : dist;
  r.speed = sqrt(r.v0 * r.v0 + (r.horizM > 0 ? vh * vh : 0));
  r.pushMs = jPushMs;
  r.impactG = peakAcc / GRAVITY;

  r.takeoffPads = jPrePeaks;
  r.takeoffLabel = jTakeoffLabel(jPrePeaks);
  r.landPads = jrPeaks(jTouchT - 20, jTouchT + JUMP_LAND_WINDOW_MS);
  r.landLabel = jLandingLabel(jTouchT - 40, jTouchT + JUMP_LAND_WINDOW_MS, r.landPads);

  jumps.add(r);
  while (jumps.size() > JUMP_MAX_KEEP) jumps.remove(0);
  jNote = "Jump " + r.n + " recorded.";
  jResetReference();
}

// ---------- stance labels ----------
String jBalanceText(float[] p) {
  if (p[0] + p[1] < FOOT_ON) return "";
  float b = (p[0] - p[1]) / max(p[0] + p[1], 1);     // MF is medial, LF is lateral
  if (b > JUMP_BALANCE)  return " (medial)";
  if (b < -JUMP_BALANCE) return " (lateral)";
  return "";
}

String jTakeoffLabel(float[] p) {
  boolean fore = p[0] > FOOT_ON || p[1] > FOOT_ON || p[2] > FOOT_ON;
  boolean heel = p[3] > HEEL_ON;
  String base = (fore && heel) ? "Flat foot" : fore ? "Forefoot" : heel ? "Heel" : "Light";
  return base + jBalanceText(p);
}

// Which part of the foot touches first, from the order the sensors pass their contact level
String jLandingLabel(int tFrom, int tTo, float[] peaks) {
  int[] first = { Integer.MAX_VALUE, Integer.MAX_VALUE, Integer.MAX_VALUE, Integer.MAX_VALUE };
  for (int k = jrCount - 1; k >= 0; k--) {                // oldest to newest
    int i = jrIdx(k);
    if (jrT[i] < tFrom) continue;
    if (jrT[i] > tTo) break;
    for (int s = 0; s < 4; s++) {
      float thr = (s == 3) ? HEEL_ON : FOOT_ON;
      if (jrP[i][s] > thr && first[s] == Integer.MAX_VALUE) first[s] = jrT[i];
    }
  }
  int earliest = min(min(first[0], first[1]), min(first[2], first[3]));
  if (earliest == Integer.MAX_VALUE) return "Light";
  boolean heel = first[3] - earliest <= 20;
  boolean fore = min(first[0], first[1]) - earliest <= 20;
  boolean mid  = first[2] - earliest <= 20;
  String base = (heel && (fore || mid)) ? "Flat" : heel ? "Heel-first" : fore ? "Forefoot-first" : "Mid-foot first";
  return base + jBalanceText(peaks);
}

String jHorizText(JumpResult r) {
  if (r.horizM == 0) return "0.00 m";
  return "~" + nf(r.horizM, 0, 2) + " m" + (r.horizOK ? "" : " ?");
}

// ---------- screen ----------
void jumpEnsureImages() {
  if (rightFootImg == null) {
    leftFootImg  = loadImage("Left_foot.png");
    rightFootImg = loadImage("Right_foot.png");
  }
}

// Same drawing as the Sensor Analysis heatmap, at a chosen position
void drawJumpFoot(float x, float y, float w, float[] v) {
  PImage img = rightFootImg;
  float h = w * img.height / img.width;
  image(img, x, y, w, h);
  for (int i = 0; i < 4; i++) {
    float px = x + (1 - hmPoints[i][0]) * w;     // mirrored, as in drawHeatmap()
    float py = y + hmPoints[i][1] * h;
    drawPressureRings(px, py, v[i], w * 0.035);
  }
}

void drawJumpAnalysis() {
  jumpEnsureImages();
  background(242);

  JumpResult r = jumps.isEmpty() ? null : jumps.get(jumps.size() - 1);
  float[] tp = r == null ? new float[4] : r.takeoffPads;
  float[] lp = r == null ? new float[4] : r.landPads;

  // ---- left panel: pressure at takeoff and landing ----
  noStroke(); fill(255);
  rect(0, 0, DIVX, height);
  stroke(200); strokeWeight(1);
  line(DIVX, 0, DIVX, height);

  fill(30); textAlign(LEFT, TOP); textSize(14);
  text("Jump Analysis", PAD, 8);

  float footW = 140;
  float fx1 = 35, fx2 = DIVX - 35 - footW, fy = 62;
  fill(60); textAlign(CENTER, TOP); textSize(12);
  text("TAKEOFF", fx1 + footW / 2, 40);
  text("LANDING", fx2 + footW / 2, 40);
  drawJumpFoot(fx1, fy, footW, tp);
  drawJumpFoot(fx2, fy, footW, lp);
  float fh = footW * rightFootImg.height / rightFootImg.width;
  fill(30); textSize(13);
  text(r == null ? "—" : r.takeoffLabel, fx1 + footW / 2, fy + fh + 10);
  text(r == null ? "—" : r.landLabel,    fx2 + footW / 2, fy + fh + 10);

  fill(130); textAlign(LEFT, TOP); textSize(10);
  text("Rings show the peak pressure of the latest jump.\n1) Stand still for about 1 s\n2) Jump and land on both feet\n3) Stay still for a moment",
       PAD * 2, height - 70);

  // ---- right panel: latest jump ----
  int rx = DIVX, rw = width - DIVX;
  int bw = (rw - 4 * PAD) / 3, bh = 93;
  int bxa = rx + PAD, bxb = bxa + bw + PAD, bxc = bxb + bw + PAD;
  int bya = 44, byb = bya + bh + PAD, byc = byb + bh + PAD;

  float best = -1;
  for (JumpResult j : jumps) best = max(best, j.heightCm);

  drawInfoBox("Jump Height (vertical)", r == null ? "—" : nf(r.heightCm, 0, 1) + " cm", bxa, bya, bw, bh);
  drawInfoBox("Flight Time",            r == null ? "—" : r.flightMs + " ms",           bxb, bya, bw, bh);
  drawInfoBox("Takeoff Speed",          r == null ? "—" : nf(r.speed, 0, 2) + " m/s",   bxc, bya, bw, bh);
  drawInfoBox("Horizontal Distance",    r == null ? "—" : jHorizText(r),                bxa, byb, bw, bh);
  drawInfoBox("Push-off Time",          (r == null || r.pushMs == 0) ? "—" : r.pushMs + " ms", bxb, byb, bw, bh);
  drawInfoBox("Landing Impact (peak)",  r == null ? "—" : nf(r.impactG, 0, 1) + " g",   bxc, byb, bw, bh);
  drawInfoBox("Takeoff Stance",         r == null ? "—" : r.takeoffLabel,               bxa, byc, bw, bh);
  drawInfoBox("Landing Stance",         r == null ? "—" : r.landLabel,                  bxb, byc, bw, bh);
  drawInfoBox("Jumps / Best",           jumps.size() + " / " + (best < 0 ? "—" : nf(best, 0, 1) + " cm"), bxc, byc, bw, bh);

  // ---- status ----
  String state = jState == 0 ? (jQ == null ? "Ready. Stand still, then jump." : "Ready. Reference set, jump when you like.")
               : jState == 1 ? "AIRBORNE  " + nf((jLastT - jOffT) / 1000.0, 0, 2) + " s"
               :               "Landing...";
  fill(50); textAlign(LEFT, CENTER); textSize(13);
  text("State:  " + state, bxa, 352);
  fill(70, 120, 220);
  text(jNote, bxa, 372);

  // ---- table of this session's jumps ----
  int tx = rx + PAD;
  int[] col = { 0, 30, 100, 170, 240, 310, 380, 540 };
  String[] head = { "#", "Height", "Flight", "Horiz.", "Speed", "Impact", "Takeoff", "Landing" };
  fill(130); textAlign(LEFT, TOP); textSize(11);
  for (int c = 0; c < head.length; c++) text(head[c], tx + col[c], 396);
  stroke(215); line(tx, 412, width - PAD, 412);

  int n = jumps.size();
  for (int k = 0; k < n; k++) {
    JumpResult j = jumps.get(n - 1 - k);
    int ry = 418 + k * 20;
    if (j.heightCm == best) {
      noStroke(); fill(255, 245, 200);
      rect(tx - 4, ry - 2, rw - 2 * PAD + 8, 18, 3);
    }
    fill(40); textAlign(LEFT, TOP); textSize(11);
    text(j.n,                              tx + col[0], ry);
    text(nf(j.heightCm, 0, 1) + " cm",     tx + col[1], ry);
    text(j.flightMs + " ms",               tx + col[2], ry);
    text(jHorizText(j),                    tx + col[3], ry);
    text(nf(j.speed, 0, 2) + " m/s",       tx + col[4], ry);
    text(nf(j.impactG, 0, 1) + " g",       tx + col[5], ry);
    text(j.takeoffLabel,                   tx + col[6], ry);
    text(j.landLabel,                      tx + col[7], ry);
  }

  // ---- buttons ----
  fill(230); stroke(180); strokeWeight(1);
  rect(DIVX + PAD, PAD - 4, 68, 24, 4);
  rect(DIVX + PAD + 78, PAD - 4, 68, 24, 4);
  fill(60); textAlign(CENTER, CENTER); textSize(11);
  text("← Back", DIVX + PAD + 34, PAD + 8);
  text("Clear",  DIVX + PAD + 78 + 34, PAD + 8);
  drawRecordBtn();
}

void jumpClick() {
  if (recordBtnHit()) {
    toggleRecording();
  } else if (mouseOver(DIVX + PAD, PAD - 4, 68, 24)) {
    stopRecording();
    screen = 0;
  } else if (mouseOver(DIVX + PAD + 78, PAD - 4, 68, 24)) {
    jumps.clear();
    jumpCount = 0;
    jNote = "Cleared.";
  }
}
