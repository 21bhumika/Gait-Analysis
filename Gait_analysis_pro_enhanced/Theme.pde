import java.util.HashMap;
import java.util.Calendar;

final color C_BG = #F2F2F7, C_CARD = #FFFFFF, C_LABEL = #1C1C1E, C_SECOND = #8E8E93, C_SEP = #E5E5EA, C_FILL = #E3E3E8;
final color C_PINK = #FF2D55, C_ORANGE = #FF9500, C_RED = #FF5E3A, C_GREEN = #34C759, C_BLUE = #007AFF;
final color C_PURPLE = #AF52DE, C_TEAL = #30B0C7, C_INDIGO = #5856D6, C_YELLOW = #E0A800;

final int SIDE_W = 210, CX = 234, CW = 842;
final int CARD_R = 14;

final color[] GAIT_COLORS = {C_GREEN, C_ORANGE, C_PURPLE, C_PINK, C_BLUE};
final color[] NAV_COLORS = {C_PINK, C_GREEN, C_RED, C_INDIGO, C_BLUE};

PFont fontR, fontB;
HashMap<String, Float> anims = new HashMap<String, Float>();
boolean handCursor = false;

void initTheme() {
  fontR = pickFont(".SFNS-Regular", "HelveticaNeue");
  fontB = pickFont(".SFNS-Bold", "HelveticaNeue-Bold");
}

PFont pickFont(String wanted, String fallback) {
  for (String name : PFont.list()) {
    if (name.equals(wanted)) return createFont(wanted, 48, true);
  }
  return createFont(fallback, 48, true);
}

void tx(float size, boolean bold, color c, int alignX, int alignY) {
  textFont(bold ? fontB : fontR, size);
  fill(c);
  textAlign(alignX, alignY);
}

float anim(String key, float target) {
  Float now = anims.get(key);
  float next = now == null ? target : now + (target - now) * 0.16;
  if (abs(next - target) < 0.002) next = target;
  anims.put(key, next);
  return next;
}

boolean hot(int x, int y, int w, int h) {
  boolean over = mouseOver(x, y, w, h);
  if (over) handCursor = true;
  return over;
}

void card(int x, int y, int w, int h) {
  noStroke();
  fill(0, 7);
  rect(x, y + 2, w, h, CARD_R);
  fill(C_CARD);
  rect(x, y, w, h, CARD_R);
}

void tapCard(int x, int y, int w, int h) {
  boolean over = hot(x, y, w, h);
  card(x, y, w, h);
  if (over) {
    noStroke();
    fill(0, 6);
    rect(x, y, w, h, CARD_R);
  }
}

void cardHeader(int x, int y, int w, String kind, String title, color c, String trailing, boolean chevron) {
  icon(kind, x + 22, y + 22, 16, c);
  tx(14, true, c, LEFT, CENTER);
  text(title, x + 36, y + 21);

  int right = x + w - 14;
  if (chevron) {
    stroke(#C7C7CC); strokeWeight(2); noFill();
    line(right - 5, y + 16, right, y + 21);
    line(right, y + 21, right - 5, y + 26);
    right -= 12;
  }
  if (trailing.length() > 0) {
    tx(12, false, C_SECOND, RIGHT, CENTER);
    text(trailing, right, y + 21);
  }
}

void metric(String value, String unit, int x, int baseline, float size, int maxW) {
  textFont(fontB, size);
  float vw = textWidth(value);
  textFont(fontB, size * 0.42);
  float uw = unit.length() > 0 ? textWidth(unit) + 5 : 0;
  float scale = vw + uw > maxW ? maxW / (vw + uw) : 1;

  tx(size * scale, true, C_LABEL, LEFT, BASELINE);
  text(value, x, baseline);
  if (unit.length() > 0) {
    tx(size * 0.42 * scale, true, C_SECOND, LEFT, BASELINE);
    text(unit, x + (vw * scale) + 5, baseline);
  }
}

String numberPart(String text) {
  int gap = text.lastIndexOf(' ');
  return gap < 0 ? text : text.substring(0, gap);
}

String unitPart(String text) {
  int gap = text.lastIndexOf(' ');
  return gap < 0 ? "" : text.substring(gap + 1);
}

void pageTitle(String title, String subtitle) {
  if (subtitle.length() > 0) {
    tx(13, true, C_SECOND, LEFT, TOP);
    text(subtitle.toUpperCase(), CX, 20);
  }
  tx(34, true, C_LABEL, LEFT, TOP);
  text(title, CX, 36);
}

void barChart(float[] values, int x, int y, int w, int h, color c) {
  float top = 0;
  int used = 0;
  for (float v : values) {
    top = max(top, v);
    if (v > 0) used++;
  }
  float gap = 3, bw = (w - gap * (values.length - 1)) / values.length;
  noStroke();
  for (int i = 0; i < values.length; i++) {
    float bx = x + i * (bw + gap);
    if (values[i] <= 0 || top <= 0) {
      fill(C_SEP);
      rect(bx, y + h - 3, bw, 3, 1.5);
    } else {
      float bh = max(4, h * values[i] / top);
      fill(c, i == values.length - 1 ? 255 : 110);
      rect(bx, y + h - bh, bw, bh, min(bw / 2, 3));
    }
  }
}

void ring(float cx, float cy, float d, float weight, float frac, color c) {
  noFill();
  strokeCap(ROUND);
  strokeWeight(weight);
  stroke(c, 45);
  ellipse(cx, cy, d, d);
  if (frac > 0.002) {
    stroke(c);
    arc(cx, cy, d, d, -HALF_PI, -HALF_PI + TWO_PI * min(frac, 0.999));
  }
  strokeCap(SQUARE);
  strokeWeight(1);
}

void gaitRing(float cx, float cy, float d, float weight) {
  float total = 0;
  for (int ms : gaitMs) total += ms;
  noFill();
  strokeWeight(weight);
  strokeCap(SQUARE);
  stroke(C_SEP);
  ellipse(cx, cy, d, d);
  if (total > 0) {
    float start = -HALF_PI;
    for (int i = 0; i < gaitMs.length; i++) {
      float sweep = TWO_PI * anim("ring" + i, gaitMs[i] / total);
      if (sweep > 0.01) {
        stroke(GAIT_COLORS[i]);
        arc(cx, cy, d, d, start, start + sweep - 0.03);
      }
      start += sweep;
    }
  }
  strokeWeight(1);
}

void segmented(int x, int y, int w, int h, String[] labels, int selected, String key) {
  noStroke();
  fill(C_FILL);
  rect(x, y, w, h, 9);

  float sw = float(w) / labels.length;
  float pos = anim(key, selected);
  fill(0, 14);
  rect(x + 2 + pos * sw, y + 3, sw - 4, h - 4, 7);
  fill(255);
  rect(x + 2 + pos * sw, y + 2, sw - 4, h - 4, 7);

  for (int i = 0; i < labels.length; i++) {
    if (i != selected) hot(x + round(i * sw), y, round(sw), h);
    tx(13, i == selected, C_LABEL, CENTER, CENTER);
    text(labels[i], x + (i + 0.5) * sw, y + h / 2 - 1);
  }
}

int segmentHit(int x, int y, int w, int h, int count) {
  if (!mouseOver(x, y, w, h)) return -1;
  return constrain(int((mouseX - x) * count / float(w)), 0, count - 1);
}

void pillButton(String label, int x, int y, int w, int h, color c, boolean filled) {
  boolean over = hot(x, y, w, h);
  noStroke();
  fill(c, filled ? (over ? 225 : 255) : (over ? 50 : 30));
  rect(x, y, w, h, h / 2.0);
  tx(14, true, filled ? color(255) : c, CENTER, CENTER);
  text(label, x + w / 2, y + h / 2 - 1);
}

void toggleSwitch(int x, int y, boolean on, String key) {
  hot(x, y, 50, 30);
  float pos = anim(key, on ? 1 : 0);
  noStroke();
  fill(lerpColor(C_FILL, C_GREEN, pos));
  rect(x, y, 50, 30, 15);
  fill(0, 25);
  ellipse(x + 15 + pos * 20, y + 16, 26, 26);
  fill(255);
  ellipse(x + 15 + pos * 20, y + 15, 26, 26);
}

void icon(String kind, float x, float y, float s, color c) {
  float h = s / 2;
  pushStyle();
  strokeCap(ROUND);
  noStroke();
  fill(c);
  if (kind.equals("heart")) {
    ellipse(x - h * 0.45, y - h * 0.25, h * 1.1, h * 1.1);
    ellipse(x + h * 0.45, y - h * 0.25, h * 1.1, h * 1.1);
    triangle(x - h * 0.97, y - h * 0.05, x + h * 0.97, y - h * 0.05, x, y + h);
  } else if (kind.equals("steps")) {
    ellipse(x - h * 0.45, y + h * 0.3, h * 0.75, h * 1.3);
    ellipse(x + h * 0.45, y - h * 0.3, h * 0.75, h * 1.3);
  } else if (kind.equals("gait")) {
    ellipse(x + h * 0.15, y - h * 0.7, h * 0.6, h * 0.6);
    stroke(c); strokeWeight(s * 0.13); noFill();
    line(x + h * 0.1, y - h * 0.25, x - h * 0.05, y + h * 0.3);
    line(x - h * 0.05, y + h * 0.3, x - h * 0.55, y + h);
    line(x - h * 0.05, y + h * 0.3, x + h * 0.5, y + h);
    line(x + h * 0.05, y - h * 0.1, x - h * 0.6, y + h * 0.1);
    line(x + h * 0.05, y - h * 0.1, x + h * 0.7, y + h * 0.1);
  } else if (kind.equals("cadence")) {
    float[] bars = {0.5, 1, 0.7};
    for (int i = 0; i < 3; i++) {
      rect(x - h + i * h * 0.75, y + h - s * bars[i], h * 0.5, s * bars[i], 1);
    }
  } else if (kind.equals("speed")) {
    stroke(c); strokeWeight(s * 0.14); noFill();
    arc(x, y + h * 0.35, s * 0.9, s * 0.9, PI, TWO_PI);
    line(x, y + h * 0.35, x + h * 0.45, y - h * 0.3);
  } else if (kind.equals("balance")) {
    arc(x, y, s * 0.9, s * 0.9, HALF_PI, PI + HALF_PI);
    stroke(c); strokeWeight(s * 0.1); noFill();
    ellipse(x, y, s * 0.9, s * 0.9);
  } else if (kind.equals("jump")) {
    stroke(c); strokeWeight(s * 0.15); noFill();
    line(x, y + h * 0.5, x, y - h * 0.7);
    line(x, y - h * 0.8, x - h * 0.55, y - h * 0.2);
    line(x, y - h * 0.8, x + h * 0.55, y - h * 0.2);
    line(x - h * 0.8, y + h * 0.9, x + h * 0.8, y + h * 0.9);
  } else if (kind.equals("time")) {
    stroke(c); strokeWeight(s * 0.12); noFill();
    ellipse(x, y, s * 0.9, s * 0.9);
    line(x, y, x, y - h * 0.55);
    line(x, y, x + h * 0.4, y);
  } else if (kind.equals("ruler")) {
    stroke(c); strokeWeight(s * 0.1); noFill();
    rect(x - h, y - h * 0.4, s, h * 0.8, 1);
    for (int i = 1; i < 4; i++) line(x - h + i * s / 4, y - h * 0.4, x - h + i * s / 4, y);
  } else if (kind.equals("width")) {
    stroke(c); strokeWeight(s * 0.13); noFill();
    line(x - h, y, x + h, y);
    line(x - h, y, x - h * 0.5, y - h * 0.45);
    line(x - h, y, x - h * 0.5, y + h * 0.45);
    line(x + h, y, x + h * 0.5, y - h * 0.45);
    line(x + h, y, x + h * 0.5, y + h * 0.45);
  } else if (kind.equals("game")) {
    rect(x - h, y - h * 0.55, s, h * 1.1, 3);
    fill(255);
    ellipse(x - h * 0.45, y, h * 0.4, h * 0.4);
    ellipse(x + h * 0.45, y, h * 0.4, h * 0.4);
  } else if (kind.equals("person")) {
    ellipse(x, y - h * 0.45, h * 0.95, h * 0.95);
    arc(x, y + h, s * 0.95, s * 1.05, PI, TWO_PI);
  } else if (kind.equals("foot")) {
    ellipse(x, y + h * 0.15, h * 0.95, s * 0.85);
    for (int i = 0; i < 3; i++) ellipse(x - h * 0.3 + i * h * 0.3, y - h * 0.75, h * 0.28, h * 0.32);
  } else {
    ellipse(x, y, s * 0.6, s * 0.6);
  }
  popStyle();
}

String todayText() {
  String[] days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
  String[] months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  Calendar now = Calendar.getInstance();
  return days[now.get(Calendar.DAY_OF_WEEK) - 1] + ", " + day() + " " + months[month() - 1];
}

void pushHistory(float[] history, float value) {
  arrayCopy(history, 1, history, 0, history.length - 1);
  history[history.length - 1] = value;
}
