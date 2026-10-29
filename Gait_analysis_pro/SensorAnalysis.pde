// ── Serial / data ────────────────────────────────────────────────
// Arduino format: DATA,MF,LF,MM,HEEL,ax,ay,az,motion,activitySec
// Baud: 115200  |  Rate: 20 Hz (every 50 ms)

Serial port;
final int BUF = 200;
float[] mfBuf   = new float[BUF];
float[] lfBuf   = new float[BUF];
float[] mmBuf   = new float[BUF];
float[] heelBuf = new float[BUF];

float ax = 0, ay = 0, az = 0;
float activitySec = 0;

int   stepCount  = 0;
float cadence    = 0;
String gaitLabel = "Normal Gait";
boolean inMotion = false;

void initSerial() {
  println("Available ports:");
  printArray(Serial.list());
  // Change index if your Arduino is not on the first port
  port = new Serial(this, Serial.list()[0], 115200);
  port.bufferUntil('\n');
}

void serialEvent(Serial p) {
  String raw = trim(p.readStringUntil('\n'));
  if (raw == null || !raw.startsWith("DATA,")) return;
  String[] v = split(raw, ',');
  if (v.length < 10) return;

  pushSample(float(v[1]), float(v[2]), float(v[3]), float(v[4]));
  ax = float(v[5]);
  ay = float(v[6]);
  az = float(v[7]);
  inMotion    = v[8].equals("1");
  activitySec = float(v[9]);
}

void pushSample(float mf, float lf, float mm, float heel) {
  arrayCopy(mfBuf,   1, mfBuf,   0, BUF - 1);
  arrayCopy(lfBuf,   1, lfBuf,   0, BUF - 1);
  arrayCopy(mmBuf,   1, mmBuf,   0, BUF - 1);
  arrayCopy(heelBuf, 1, heelBuf, 0, BUF - 1);
  mfBuf[BUF-1] = mf;  lfBuf[BUF-1] = lf;
  mmBuf[BUF-1] = mm;  heelBuf[BUF-1] = heel;
}

// ── Layout constants ─────────────────────────────────────────────
final int DIVX  = 1100 / 3;   // vertical divider x
final int DIVY  = 700  / 2;   // horizontal divider y (right side)
final int PAD   = 10;
final int TITLE = 24;          // height reserved for section titles

// ── Top-level draw call ──────────────────────────────────────────
void drawSensorAnalysis() {
  background(242, 242, 242);
  drawSADividers();
  drawHeatmap();
  drawFSRGraphs();
  drawInfoPanel();
  drawSABackBtn();
}

// ── Dividers ─────────────────────────────────────────────────────
void drawSADividers() {
  stroke(200); strokeWeight(1);
  line(DIVX, 0, DIVX, height);
  line(DIVX, DIVY, width, DIVY);
}

// ── Left 1/3: heatmap placeholder ────────────────────────────────
void drawHeatmap() {
  noStroke(); fill(248);
  rect(0, 0, DIVX, height);

  fill(80); textAlign(CENTER, TOP); textSize(13);
  text("Pressure Heatmap", DIVX / 2, 14);

  fill(225); stroke(190); strokeWeight(1);
  rect(PAD + 5, 45, DIVX - (PAD + 5) * 2, height - 60, 6);

  fill(155); noStroke(); textSize(12); textAlign(CENTER, CENTER);
  text("[ Not Implemented ]", DIVX / 2, height / 2);
}

// ── Top-right: 4 FSR graphs in 2×2 grid ─────────────────────────
void drawFSRGraphs() {
  int rx = DIVX, rw = width - DIVX, rh = DIVY;

  fill(60); textAlign(LEFT, TOP); textSize(12);
  text("FSR Sensor Readings", rx + PAD, 8);

  int gw = (rw - 3 * PAD) / 2;
  int gh = (rh - 2 * PAD - TITLE) / 2;
  int x0 = rx + PAD,      x1 = rx + PAD + gw + PAD;
  int y0 = TITLE,          y1 = TITLE + gh + PAD;

  drawGraph("Lateral Forefoot (LF)", lfBuf,   x0, y0, gw, gh, color(220, 190, 0));
  drawGraph("Medial Forefoot (MF)",  mfBuf,   x1, y0, gw, gh, color(210, 40,  40));
  drawGraph("Medial Mid-foot (MM)",  mmBuf,   x0, y1, gw, gh, color(50,  160, 70));
  drawGraph("Heel",                  heelBuf, x1, y1, gw, gh, color(50,  100, 210));
}

void drawGraph(String label, float[] data, int x, int y, int w, int h, color c) {
  fill(255); stroke(205); strokeWeight(1);
  rect(x, y, w, h, 5);

  fill(90); textAlign(LEFT, TOP); textSize(10);
  text(label, x + 5, y + 5);

  stroke(c); strokeWeight(1.5);
  for (int i = 1; i < data.length; i++) {
    float x1 = x + map(i - 1, 0, data.length - 1, 4, w - 4);
    float y1 = y + map(data[i - 1], 0, 1023, h - 6, 20);
    float x2 = x + map(i,     0, data.length - 1, 4, w - 4);
    float y2 = y + map(data[i],     0, 1023, h - 6, 20);
    line(x1, y1, x2, y2);
  }
}

// ── Bottom-right: 4 info boxes ───────────────────────────────────
void drawInfoPanel() {
  int rx = DIVX, rw = width - DIVX, ry = DIVY, rh = height - DIVY;

  noStroke(); fill(248);
  rect(rx, ry, rw, rh);

  fill(60); textAlign(LEFT, TOP); textSize(12);
  text("Gait Info", rx + PAD, ry + 8);

  int bw = (rw - 3 * PAD) / 2;
  int bh = (rh - 2 * PAD - TITLE) / 2;
  int x0 = rx + PAD,       x1 = rx + PAD + bw + PAD;
  int y0 = ry + TITLE,      y1 = ry + TITLE + bh + PAD;

  drawInfoBox("Step Count",    str(stepCount),                    x0, y0, bw, bh);
  drawInfoBox("Cadence",       "— steps/min",                     x1, y0, bw, bh);
  drawInfoBox("Gait Profile",  gaitLabel,                         x0, y1, bw, bh);
  drawInfoBox("Status",        inMotion ? "In Motion" : "Standing", x1, y1, bw, bh);
}

void drawInfoBox(String label, String value, int x, int y, int w, int h) {
  fill(255); stroke(210); strokeWeight(1);
  rect(x, y, w, h, 6);

  fill(130); textAlign(LEFT, TOP); textSize(10);
  text(label, x + 8, y + 6);

  fill(30); textAlign(LEFT, BOTTOM); textSize(16);
  text(value, x + 8, y + h - 6);
}

// ── Back button ──────────────────────────────────────────────────
void drawSABackBtn() {
  fill(230); stroke(180); strokeWeight(1);
  rect(DIVX + PAD, PAD - 4, 68, 24, 4);
  fill(60); textAlign(CENTER, CENTER); textSize(11);
  text("← Back", DIVX + PAD + 34, PAD + 8);
}

void sensorClick() {
  if (mouseX >= DIVX + PAD && mouseX <= DIVX + PAD + 68 &&
      mouseY >= PAD - 4    && mouseY <= PAD + 20) {
    screen = 0;
  }
}
