// Serial / data
// Arduino format: DATA,MF,LF,MM,HEEL,ax,ay,az,motion,activitySec,gx,gy,gz,timeMs
// Baud: 115200  |  Rate: 50 Hz (every 20 ms)

Serial port;
final int BUF = 500;
final int SAMPLE_HZ = 50;
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
  port = new Serial(this, Serial.list()[0], 115200);
  port.bufferUntil('\n');
}

void serialEvent(Serial p) {
  handleLine(trim(p.readStringUntil('\n')));
}

void handleLine(String raw) {
  if (raw == null || !raw.startsWith("DATA,")) return;
  String[] v = split(raw, ',');
  if (v.length < 10) return;

  for (int i = 0; i < rawCh.length; i++) rawCh[i] = float(v[i + 1]);
  int[] c = profile.ch;
  pushSample(float(v[c[0]]), float(v[c[1]]), float(v[c[2]]), float(v[c[3]]));

  ax = float(v[5]);
  ay = float(v[6]);
  az = float(v[7]);
  inMotion    = v[8].equals("1");
  activitySec = float(v[9]);
  updateGait(millis());
  if (v.length >= 14) {
    gyroX = float(v[10]);
    gyroY = float(v[11]);
    gyroZ = float(v[12]);
    boardMs = int(v[13]);
    updateStride(gyroX, gyroY, gyroZ, ax, ay, az, boardMs);
  }
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

// Layout constants 
final int DIVX  = 1100 / 3;   // vertical divider x
final int DIVY  = 700  / 2;   // horizontal divider y (right side)
final int PAD   = 10;
final int TITLE = 24;          // height reserved for section titles

// Top-level draw call 
void drawSensorAnalysis() {
  background(242, 242, 242);
  drawSADividers();
  drawHeatmap();
  drawFSRGraphs();
  drawInfoPanel();
  drawGaitTimes();
  drawSABackBtn();
  drawRecordBtn();
  drawProfileBtn();
}

// Dividers 
void drawSADividers() {
  stroke(200); strokeWeight(1);
  line(DIVX, 0, DIVX, height);
  line(DIVX, DIVY, width, DIVY);
}

// Left 1/3: heatmap, see Heatmap.pde 

// Top-right: 4 FSR graphs in 2×2 grid 
void drawFSRGraphs() {
  int rx = DIVX, rw = width - DIVX, rh = DIVY;

  fill(60); textAlign(LEFT, TOP); textSize(12);
  text("FSR Sensor Readings", rx + PAD, 8);

  int gw = (rw - 3 * PAD) / 2;
  int gh = (rh - 2 * PAD - TITLE) / 2;
  int x0 = rx + PAD,      x1 = rx + PAD + gw + PAD;
  int y0 = TITLE,          y1 = TITLE + gh + PAD;

  drawGraph("Lateral Forefoot (LF)", lfBuf,   x0, y0, gw, gh, color(220, 190, 0),  FOOT_ON);
  drawGraph("Medial Forefoot (MF)",  mfBuf,   x1, y0, gw, gh, color(210, 40,  40), FOOT_ON);
  drawGraph("Medial Mid-foot (MM)",  mmBuf,   x0, y1, gw, gh, color(50,  160, 70), FOOT_ON);
  drawGraph("Heel",                  heelBuf, x1, y1, gw, gh, color(50,  100, 210), HEEL_ON);
}

void drawGraph(String label, float[] data, int x, int y, int w, int h, color c, float contactLine) {
  fill(255); stroke(205); strokeWeight(1);
  rect(x, y, w, h, 5);

  fill(90); textAlign(LEFT, TOP); textSize(10);
  text(label, x + 5, y + 5);

  int px = x + 30, pw = w - 38;
  int py = y + 20, ph = h - 36;
  int windowSec = BUF / SAMPLE_HZ;

  textSize(9); strokeWeight(1);
  for (int v = 0; v <= 1000; v += 250) {
    float gy = py + map(v, 0, 1023, ph, 0);
    stroke(232); line(px, gy, px + pw, gy);
    fill(130); textAlign(RIGHT, CENTER);
    text(v, px - 4, gy);
  }
  for (int s = 0; s <= windowSec; s += 2) {
    float gx = px + map(s, windowSec, 0, 0, pw);
    stroke(232); line(gx, py, gx, py + ph);
    if (s == windowSec) continue;   // would collide with the 0 on the value axis
    fill(130); textAlign(s == 0 ? RIGHT : CENTER, TOP);
    text(s == 0 ? "now" : "-" + s + "s", gx, py + ph + 2);
  }

  float cy = py + map(contactLine, 0, 1023, ph, 0);
  stroke(c, 110); line(px, cy, px + pw, cy);
  fill(c); textAlign(LEFT, BOTTOM);
  text("contact", px + 3, cy - 1);

  stroke(c); strokeWeight(1.5);
  for (int i = 1; i < data.length; i++) {
    float x1 = px + map(i - 1, 0, data.length - 1, 0, pw);
    float y1 = py + map(data[i - 1], 0, 1023, ph, 0);
    float x2 = px + map(i,     0, data.length - 1, 0, pw);
    float y2 = py + map(data[i],     0, 1023, ph, 0);
    line(x1, y1, x2, y2);
  }
}

// Bottom-right: 3×3 info boxes
void drawInfoPanel() {
  int rx = DIVX, rw = width - DIVX, ry = DIVY, rh = height - DIVY;

  noStroke(); fill(248);
  rect(rx, ry, rw, rh);

  fill(60); textAlign(LEFT, TOP); textSize(12);
  text("Gait Info", rx + PAD, ry + 8);

  int bw = (rw - 4 * PAD) / 3;
  int bh = (rh - 3 * PAD - TITLE) / 3;
  int x0 = rx + PAD,        x1 = x0 + bw + PAD,   x2 = x1 + bw + PAD;
  int y0 = ry + TITLE,      y1 = y0 + bh + PAD,   y2 = y1 + bh + PAD;

  drawInfoBox("Step Count",           str(stepCount),                      x0, y0, bw, bh);
  drawInfoBox("Cadence",              cadenceText(),                       x1, y0, bw, bh);
  drawInfoBox("Gait Profile",         gaitLabel,                           x2, y0, bw, bh);
  drawInfoBox("Status",               inMotion ? "In Motion" : "Standing", x0, y1, bw, bh);
  drawInfoBox("Motion Time (this walk)", formatTime(motionMs()),           x1, y1, bw, bh);
  drawInfoBox("Stride Time",          strideTimeText(),                    x2, y1, bw, bh);
  String source = gyroStrideM > 0 ? " (from gyro)" : " (est. from height)";
  drawInfoBox("Stride Length" + source, strideLengthText(),                x0, y2, bw, bh);
  drawInfoBox(profile.stepWidthCm > 0 ? "Step Width (entered)" : "Step Width",
              stepWidthText(),                                             x1, y2, bw, bh);
  drawInfoBox("Walking Speed" + source, speedText(),                       x2, y2, bw, bh);
}

void drawInfoBox(String label, String value, int x, int y, int w, int h) {
  fill(255); stroke(210); strokeWeight(1);
  rect(x, y, w, h, 6);

  fill(130); textAlign(LEFT, TOP); textSize(10);
  text(label, x + 8, y + 6);

  fill(30); textAlign(LEFT, BOTTOM); textSize(34);
  float fit = textWidth(value);
  if (fit > w - 16) textSize(34 * (w - 16) / fit);
  text(value, x + 8, y + h - 6);
}

// Left panel, under the foot: walking time split by gait
void drawGaitTimes() {
  int x = PAD * 3, right = DIVX - PAD * 3, y = 532, rowH = 21;

  fill(60); textAlign(LEFT, TOP); textSize(12);
  text("Motion Time by Gait", x, y);
  y += 22;

  int total = 0;
  textSize(12);
  for (int i = 0; i < GAITS.length; i++) {
    total += gaitMs[i];
    drawGaitRow(GAITS[i], gaitMs[i], x, right, y + i * rowH, 90);
  }
  stroke(210); strokeWeight(1);
  line(x, y + GAITS.length * rowH, right, y + GAITS.length * rowH);
  drawGaitRow("Total", total, x, right, y + GAITS.length * rowH + 4, 30);
}

void drawGaitRow(String label, int ms, int x, int right, int y, int shade) {
  fill(shade); textAlign(LEFT, TOP);
  text(label, x, y);
  textAlign(RIGHT, TOP);
  text(formatTime(ms), right, y);
}

// Top of the left panel: opens the profile screen
final int PROFILE_BTN_W = 200, PROFILE_BTN_H = 24;

void drawProfileBtn() {
  fill(230); stroke(180); strokeWeight(1);
  rect(PAD, PAD - 4, PROFILE_BTN_W, PROFILE_BTN_H, 4);
  fill(60); textAlign(CENTER, CENTER); textSize(11);
  text("Profile: " + profile.name, PAD + PROFILE_BTN_W / 2, PAD + 8);
}

// Back button
void drawSABackBtn() {
  fill(230); stroke(180); strokeWeight(1);
  rect(DIVX + PAD, PAD - 4, 68, 24, 4);
  fill(60); textAlign(CENTER, CENTER); textSize(11);
  text("← Back", DIVX + PAD + 34, PAD + 8);
}

void sensorClick() {
  if (recordBtnHit()) {
    toggleRecording();
  } else if (mouseX >= DIVX + PAD && mouseX <= DIVX + PAD + 68 &&
             mouseY >= PAD - 4    && mouseY <= PAD + 20) {
    stopRecording();
    screen = 0;
  } else if (mouseOver(PAD, PAD - 4, PROFILE_BTN_W, PROFILE_BTN_H)) {
    stopRecording();
    screen = 3;
  }
}
