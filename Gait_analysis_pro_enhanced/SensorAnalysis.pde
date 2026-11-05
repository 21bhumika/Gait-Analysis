// Arduino format: DATA,MF,LF,MM,HEEL,ax,ay,az,motion,activitySec,gx,gy,gz,timeMs*checksum

Serial port;
final int BUF = 250;
final int SAMPLE_HZ = 25;
float[] mfBuf   = new float[BUF];
float[] lfBuf   = new float[BUF];
float[] mmBuf   = new float[BUF];
float[] heelBuf = new float[BUF];

float ax = 0, ay = 0, az = 0;
float gyroX = 0, gyroY = 0, gyroZ = 0;
int boardMs = 0;
float activitySec = 0;

int   stepCount  = 0;
float cadence    = 0;
String gaitLabel = "—";
boolean inMotion = false;

void initSerial() {
  println("Available ports:");
  printArray(Serial.list());
  // Change index if your Arduino is not on the first port
  port = new Serial(this, Serial.list()[2], 115200);
  port.bufferUntil('\n');
}

void serialEvent(Serial p) {
  handleLine(trim(p.readStringUntil('\n')));
}

int rejectedLines = 0;

boolean checksumOk(String raw) {
  int star = raw.lastIndexOf('*');
  if (star < 0 || raw.length() != star + 3) return false;

  int sum = 0;
  for (int i = 0; i < star; i++) sum ^= raw.charAt(i);
  return raw.substring(star + 1).equalsIgnoreCase(hex(sum, 2));
}

void handleLine(String raw) {
  if (raw == null || !raw.startsWith("DATA,")) return;
  lastSampleMs = millis();

  String[] v = checksumOk(raw) ? split(raw.substring(0, raw.lastIndexOf('*')), ',') : new String[0];
  if (v.length != 14) {
    if (++rejectedLines % 100 == 1) {
      println("Ignored " + rejectedLines + " damaged serial lines (is the latest Arduino code uploaded?)");
    }
    return;
  }

  for (int i = 0; i < rawCh.length; i++) rawCh[i] = float(v[i + 1]);
  int[] c = profile.ch;
  pushSample(float(v[c[0]]), float(v[c[1]]), float(v[c[2]]), float(v[c[3]]));

  ax = float(v[5]);
  ay = float(v[6]);
  az = float(v[7]);
  inMotion    = v[8].equals("1");
  activitySec = float(v[9]);
  updateGait(millis());
  gyroX = float(v[10]);
  gyroY = float(v[11]);
  gyroZ = float(v[12]);
  boardMs = int(v[13]);
  updateStride(gyroX, gyroY, gyroZ, ax, ay, az, boardMs);
  coolFeed(ax, ay, az, gyroX, gyroY, gyroZ, millis());
  jumpFeed(ax, ay, az, gyroX, gyroY, gyroZ, boardMs);
  recordSample();
}

void pushSample(float mf, float lf, float mm, float heel) {
  arrayCopy(mfBuf,   1, mfBuf,   0, BUF - 1);
  arrayCopy(lfBuf,   1, lfBuf,   0, BUF - 1);
  arrayCopy(mmBuf,   1, mmBuf,   0, BUF - 1);
  arrayCopy(heelBuf, 1, heelBuf, 0, BUF - 1);
  mfBuf[BUF-1] = mf;  lfBuf[BUF-1] = lf;
  mmBuf[BUF-1] = mm;  heelBuf[BUF-1] = heel;
}

final String[] GAIT_TABS = {"Metrics", "Sensors", "Gait Time"};
final int GT_Y = 86, GT_H = 32, GR_X = 530, GR_W = 546, GR_Y = 130, GR_H = 548;
int gaitTab = 0;

void drawSensorAnalysis() {
  pageTitle("Gait", "");
  drawRecordBtn();

  drawFootCard(CX, GT_Y, 280, 592);
  segmented(GR_X, GT_Y, GR_W, GT_H, GAIT_TABS, gaitTab, "gaitTab");

  if (gaitTab == 0) drawGaitMetrics();
  else if (gaitTab == 1) drawFSRGraphs();
  else drawGaitTime();
}

void drawFootCard(int x, int y, int w, int h) {
  card(x, y, w, h);
  cardHeader(x, y, w, "foot", "Foot Pressure", C_PURPLE, "Live", false);

  drawFootAt(x + (w - 150) / 2, y + 42, 150);

  stroke(C_SEP); strokeWeight(1);
  line(x + 14, y + 416, x + w - 14, y + 416);

  tx(13, true, C_PURPLE, LEFT, TOP);
  text("Medial Force", x + 14, y + 428);
  metric(str(round(anim("mfpLive", mfpLive))), "%", x + 14, y + 490, 44, 120);
  tx(13, false, C_SECOND, LEFT, TOP);
  text("Right now", x + 14, y + 498);

  metric(stepMfp < 0 ? "—" : str(round(stepMfp)), "%", x + 150, y + 490, 44, 120);
  tx(13, false, C_SECOND, LEFT, TOP);
  text("Last step", x + 150, y + 498);

  tx(13, false, C_SECOND, LEFT, TOP);
  text("Session " + mfpText(), x + 14, y + 538);
}

void drawGaitMetrics() {
  int w = (GR_W - 24) / 3, h = (GR_H - 24) / 3;
  int x0 = GR_X, x1 = x0 + w + 12, x2 = x1 + w + 12;
  int y0 = GR_Y, y1 = y0 + h + 12, y2 = y1 + h + 12;

  metricCard(x0, y0, w, h, "steps", "Steps", C_ORANGE, str(round(anim("steps", stepCount))), "steps", "This session");
  metricCard(x1, y0, w, h, "cadence", "Cadence", C_RED, numberPart(cadenceText()), unitPart(cadenceText()), "Average");
  metricCard(x2, y0, w, h, "gait", "Gait Profile", C_GREEN, gaitLabel, "", "Recent steps");

  metricCard(x0, y1, w, h, "heart", "Status", C_PINK, inMotion ? "In Motion" : "Standing", "", "Right now");
  metricCard(x1, y1, w, h, "time", "Activity Time", C_TEAL, formatTime((int)(activitySec * 1000)), "", "From motion sensor");
  metricCard(x2, y1, w, h, "ruler", "Step Length", C_INDIGO, numberPart(stepLengthText()), unitPart(stepLengthText()), "From profile");

  metricCard(x0, y2, w, h, "ruler", "Stride Length", C_BLUE, numberPart(strideLengthText()), unitPart(strideLengthText()), strideSource());
  metricCard(x1, y2, w, h, "width", "Step Width", C_INDIGO, numberPart(stepWidthText()), unitPart(stepWidthText()), profile.stepWidthCm > 0 ? "From profile" : "One insole only");
  metricCard(x2, y2, w, h, "speed", "Walking Speed", C_BLUE, numberPart(speedText()), unitPart(speedText()), strideSource());
}

String strideSource() {
  if (profile.stepLengthCm > 0) return "From step length";
  return gyroStrideM > 0 ? "From gyro" : "Estimated from height";
}

void metricCard(int x, int y, int w, int h, String kind, String title, color c, String value, String unit, String sub) {
  card(x, y, w, h);
  cardHeader(x, y, w, kind, title, c, "", false);
  metric(value, unit, x + 14, y + h - 44, 32, w - 26);
  tx(12, false, C_SECOND, LEFT, BASELINE);
  text(sub, x + 14, y + h - 18);
}

void drawFSRGraphs() {
  int w = (GR_W - 12) / 2, h = (GR_H - 12) / 2;
  int x0 = GR_X, x1 = x0 + w + 12;
  int y0 = GR_Y, y1 = y0 + h + 12;

  drawGraph("Lateral Forefoot",  "LF", lfBuf,   x0, y0, w, h, C_YELLOW, FOOT_ON);
  drawGraph("Medial Forefoot",   "MF", mfBuf,   x1, y0, w, h, C_RED,    FOOT_ON);
  drawGraph("Medial Mid-foot",   "MM", mmBuf,   x0, y1, w, h, C_GREEN,  FOOT_ON);
  drawGraph("Heel",              "HEEL", heelBuf, x1, y1, w, h, C_BLUE, HEEL_ON);
}

void drawGraph(String label, String shortName, float[] data, int x, int y, int w, int h, color c, float contactLine) {
  card(x, y, w, h);
  cardHeader(x, y, w, "dot", label, c, shortName, false);
  metric(str(int(data[BUF-1])), "", x + 14, y + 72, 30, 120);

  int px = x + 14, pw = w - 50;
  int py = y + 86, ph = h - 118;
  int windowSec = BUF / SAMPLE_HZ;

  for (int v = 0; v <= 1000; v += 500) {
    float gy = py + map(v, 0, 1023, ph, 0);
    stroke(C_SEP); strokeWeight(1);
    line(px, gy, px + pw, gy);
    tx(10, false, C_SECOND, LEFT, CENTER);
    text(v, px + pw + 5, gy);
  }
  for (int s = 0; s <= windowSec; s += 5) {
    float gx = px + map(s, windowSec, 0, 0, pw);
    tx(10, false, C_SECOND, s == 0 ? RIGHT : s == windowSec ? LEFT : CENTER, TOP);
    text(s == 0 ? "now" : "-" + s + "s", gx, py + ph + 5);
  }

  float cy = py + map(contactLine, 0, 1023, ph, 0);
  stroke(C_SECOND); strokeWeight(1);
  for (int d = px; d < px + pw; d += 8) line(d, cy, min(d + 4, px + pw), cy);
  tx(10, false, C_SECOND, LEFT, BOTTOM);
  text("contact", px + 2, cy - 2);

  noStroke();
  fill(c, 34);
  beginShape();
  vertex(px, py + ph);
  for (int i = 0; i < data.length; i++) {
    vertex(px + map(i, 0, data.length - 1, 0, pw), py + map(data[i], 0, 1023, ph, 0));
  }
  vertex(px + pw, py + ph);
  endShape(CLOSE);

  noFill();
  stroke(c); strokeWeight(2); strokeJoin(ROUND);
  beginShape();
  for (int i = 0; i < data.length; i++) {
    vertex(px + map(i, 0, data.length - 1, 0, pw), py + map(data[i], 0, 1023, ph, 0));
  }
  endShape();
  strokeWeight(1);
}

void drawGaitTime() {
  card(GR_X, GR_Y, GR_W, GR_H);
  cardHeader(GR_X, GR_Y, GR_W, "time", "Time by Gait", C_TEAL, "This session", false);

  int total = totalGaitMs();
  int cx = GR_X + GR_W / 2, cy = GR_Y + 170;
  gaitRing(cx, cy, 200, 30);
  metric(formatTime(total), "", cx - 44, cy + 6, 30, 100);
  tx(12, false, C_SECOND, CENTER, TOP);
  text("walking", cx, cy + 12);

  for (int i = 0; i < GAITS.length; i++) {
    int y = GR_Y + 310 + i * 42;
    gaitRow(i, GR_X + 40, y, GR_W - 80, total);
    if (i < GAITS.length - 1) {
      stroke(C_SEP); strokeWeight(1);
      line(GR_X + 58, y + 28, GR_X + GR_W - 40, y + 28);
    }
  }
}

void sensorClick() {
  if (recordBtnHit()) {
    toggleRecording();
    return;
  }
  int tab = segmentHit(GR_X, GT_Y, GR_W, GT_H, GAIT_TABS.length);
  if (tab >= 0) gaitTab = tab;
}
