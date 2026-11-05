final String[] NAV_LABELS = {"Summary", "Gait", "Jump", "Game", "Profiles"};
final String[] NAV_ICONS  = {"heart", "gait", "jump", "game", "person"};
final int[]    NAV_SCREEN = {0, 1, 4, 2, 3};
final int NAV_Y = 84, NAV_H = 40, NAV_GAP = 4;

final int SUM_W = 270, SUM_H = 156, SUM_GAP = 16, SUM_Y0 = 112, SUM_Y1 = 284;
final int[] SUM_TARGET = {1, 1, 1, 1, 1, 4};

int screenChangedAt = -1000;
int lastSampleMs = -10000;

void goTo(int next) {
  if (next == screen) return;
  if (screen == 1 || screen == 4) stopRecording();
  if (screen == 2) {
    caReleaseAll();
    pauseGame();
  }
  if (next == 2) startGame();
  if (screen == 3) {
    commitField();
    cancelTeaching();
  }
  screen = next;
  screenChangedAt = millis();
}

boolean insoleConnected() {
  return millis() - lastSampleMs < 1500;
}

void drawSidebar() {
  noStroke();
  fill(#FBFBFD);
  rect(0, 0, SIDE_W, height);
  fill(C_SEP);
  rect(SIDE_W - 1, 0, 1, height);

  icon("heart", 30, 44, 22, C_PINK);
  tx(22, true, C_LABEL, LEFT, CENTER);
  text("Gait Lab", 48, 42);

  for (int i = 0; i < NAV_LABELS.length; i++) {
    int y = NAV_Y + i * (NAV_H + NAV_GAP);
    boolean selected = screen == NAV_SCREEN[i];
    boolean over = hot(10, y, SIDE_W - 21, NAV_H);
    noStroke();
    if (selected) {
      fill(NAV_COLORS[i], 32);
      rect(10, y, SIDE_W - 21, NAV_H, 10);
    } else if (over) {
      fill(0, 10);
      rect(10, y, SIDE_W - 21, NAV_H, 10);
    }
    icon(NAV_ICONS[i], 32, y + NAV_H / 2, 18, NAV_COLORS[i]);
    tx(15, selected, selected ? NAV_COLORS[i] : C_LABEL, LEFT, CENTER);
    text(NAV_LABELS[i], 52, y + NAV_H / 2 - 1);
  }

  boolean live = insoleConnected();
  noStroke();
  fill(live ? C_GREEN : C_SECOND);
  ellipse(24, height - 70, 8, 8);
  tx(12, false, C_SECOND, LEFT, CENTER);
  text(live ? "Insole connected" : "Waiting for insole", 34, height - 71);

  boolean over = hot(10, height - 54, SIDE_W - 21, 44);
  if (over) {
    noStroke();
    fill(0, 10);
    rect(10, height - 54, SIDE_W - 21, 44, 10);
  }
  noStroke();
  fill(C_BLUE);
  ellipse(34, height - 32, 30, 30);
  tx(14, true, color(255), CENTER, CENTER);
  text(profile.name.substring(0, 1).toUpperCase(), 34, height - 33);
  tx(13, true, C_LABEL, LEFT, CENTER);
  String name = profile.name;
  while (textWidth(name) > SIDE_W - 72 && name.length() > 1) name = name.substring(0, name.length() - 1);
  text(name, 56, height - 33);
}

void sidebarClick() {
  for (int i = 0; i < NAV_LABELS.length; i++) {
    if (mouseOver(10, NAV_Y + i * (NAV_H + NAV_GAP), SIDE_W - 21, NAV_H)) goTo(NAV_SCREEN[i]);
  }
  if (mouseOver(10, height - 54, SIDE_W - 21, 44)) goTo(3);
}

int sumX(int col) {
  return CX + col * (SUM_W + SUM_GAP);
}

void drawHome() {
  pageTitle("Summary", todayText());

  tx(20, true, C_LABEL, LEFT, TOP);
  text("Pinned", CX, 82);

  summaryCard(0, 0, SUM_Y0, "steps", "Steps", C_ORANGE);
  metric(str(round(anim("steps", stepCount))), "steps", sumX(0) + 14, SUM_Y0 + 88, 36, SUM_W - 28);
  subLine("This session", 0, SUM_Y0);

  summaryCard(1, 1, SUM_Y0, "gait", "Gait", C_GREEN);
  metric(gaitLabel, "", sumX(1) + 14, SUM_Y0 + 88, 32, SUM_W - 28);
  subLine("From your recent steps", 1, SUM_Y0);

  summaryCard(2, 2, SUM_Y0, "cadence", "Cadence", C_RED);
  metric(numberPart(cadenceText()), unitPart(cadenceText()), sumX(2) + 14, SUM_Y0 + 62, 32, SUM_W - 28);
  barChart(cadenceHist, sumX(2) + 14, SUM_Y0 + 78, SUM_W - 28, 62, C_RED);

  summaryCard(3, 0, SUM_Y1, "speed", "Walking Speed", C_BLUE);
  metric(numberPart(speedText()), unitPart(speedText()), sumX(0) + 14, SUM_Y1 + 62, 32, SUM_W - 28);
  barChart(speedHist, sumX(0) + 14, SUM_Y1 + 78, SUM_W - 28, 62, C_BLUE);

  summaryCard(4, 1, SUM_Y1, "balance", "Medial Force", C_PURPLE);
  metric(stepMfp < 0 ? "—" : str(round(stepMfp)), "%", sumX(1) + 14, SUM_Y1 + 88, 36, SUM_W - 110);
  subLine("Last step", 1, SUM_Y1);
  ring(sumX(1) + SUM_W - 52, SUM_Y1 + 90, 62, 12, anim("mfp", max(stepMfp, 0) / 100), C_PURPLE);

  summaryCard(5, 2, SUM_Y1, "jump", "Jump Height", C_PINK);
  metric(jumps.isEmpty() ? "—" : str(round(jumps.get(jumps.size() - 1).heightCm)), "cm", sumX(2) + 14, SUM_Y1 + 88, 36, SUM_W - 28);
  subLine(jumps.isEmpty() ? "No jumps yet" : "Best " + round(jumpBest()) + " cm", 2, SUM_Y1);

  tx(20, true, C_LABEL, LEFT, TOP);
  text("Highlights", CX, 452);
  drawHighlights(CX, 482, CW, 196);
}

void summaryCard(int index, int col, int y, String kind, String title, color c) {
  tapCard(sumX(col), y, SUM_W, SUM_H);
  cardHeader(sumX(col), y, SUM_W, kind, title, c, "", true);
}

void subLine(String text, int col, int y) {
  tx(13, false, C_SECOND, LEFT, BASELINE);
  text(text, sumX(col) + 14, y + 112);
}

int totalGaitMs() {
  int total = 0;
  for (int ms : gaitMs) total += ms;
  return total;
}

void drawHighlights(int x, int y, int w, int h) {
  card(x, y, w, h);
  cardHeader(x, y, w, "time", "Time by Gait", C_TEAL, "", false);

  int total = totalGaitMs();
  gaitRing(x + 96, y + 112, 112, 20);
  tx(20, true, C_LABEL, CENTER, CENTER);
  text(formatTime(total), x + 96, y + 110);

  int textX = x + 186;
  int best = 0;
  for (int i = 1; i < gaitMs.length; i++) {
    if (gaitMs[i] > gaitMs[best]) best = i;
  }
  tx(20, true, C_LABEL, LEFT, TOP);
  textLeading(25);
  String headline = total == 0 ? "Walk a few steps to see how your time splits by gait."
    : "Most of your walking was " + GAITS[best] + ", " + round(100.0 * gaitMs[best] / total) + "% of this session.";
  text(headline, textX, y + 52, 270, 120);

  int listX = x + w - 310;
  for (int i = 0; i < GAITS.length; i++) {
    gaitRow(i, listX, y + 44 + i * 28, 290, total);
  }
}

void gaitRow(int i, int x, int y, int w, int total) {
  noStroke();
  fill(GAIT_COLORS[i]);
  ellipse(x + 5, y + 8, 10, 10);
  tx(14, false, C_LABEL, LEFT, CENTER);
  text(GAITS[i], x + 18, y + 7);
  tx(14, true, C_LABEL, RIGHT, CENTER);
  text(formatTime(gaitMs[i]), x + w, y + 7);
  tx(13, false, C_SECOND, RIGHT, CENTER);
  text(total == 0 ? "—" : round(100.0 * gaitMs[i] / total) + "%", x + w - 56, y + 7);
}

void homeClick() {
  for (int i = 0; i < 6; i++) {
    int col = i % 3;
    int y = i < 3 ? SUM_Y0 : SUM_Y1;
    if (mouseOver(sumX(col), y, SUM_W, SUM_H)) goTo(SUM_TARGET[i]);
  }
}
