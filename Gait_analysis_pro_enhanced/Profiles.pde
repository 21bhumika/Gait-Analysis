class Profile {
  String name;
  int[] ch = {1, 2, 3, 4};   // MF, LF, MM, HEEL -> column in the DATA line (1 = A0)
  float heightCm = 170;
  float stepWidthCm = 0;
  float stepLengthCm = 0;

  float tipHeelMax = DEFAULT_TIP_HEEL;
  float heelForeMax = DEFAULT_HEEL_FORE;
  float inToeBalance = DEFAULT_IN_TOE;
  float outToeBalance = DEFAULT_OUT_TOE;
  float[][] taught = new float[GAITS.length][];

  Profile(String name, int mf, int lf, int mm, int heel) {
    this.name = name;
    ch = new int[] {mf, lf, mm, heel};
  }
}

final String[] REGIONS = {"Medial Forefoot (MF)", "Lateral Forefoot (LF)", "Medial Mid-foot (MM)", "Heel"};

final float DEFAULT_TIP_HEEL = 600, DEFAULT_HEEL_FORE = 500;
final float DEFAULT_IN_TOE = 0.06, DEFAULT_OUT_TOE = -0.02;
final int MIN_TEACH_STEPS = 3;

ArrayList<Profile> profiles = new ArrayList<Profile>();
Profile profile;
float[] rawCh = new float[4];

final int PF_LIST_X = 234, PF_LIST_Y = 90, PF_LIST_W = 202, PF_ROW_H = 44;
final int PF_LIST_BTN_W = 94, PF_LIST_BTN_H = 32;
final int PF_CARD_X = 452, PF_CARD_W = 624;
final int PF_X = 468, PF_FIELD_H = 30, PF_NUM_Y = 124;
final int PF_NAME_W = 186, PF_HEIGHT_X = 666, PF_HEIGHT_W = 110;
final int PF_WIDTH_X = 788, PF_LENGTH_X = 930, PF_NUM_W = 130;
final int PF_TABLE_Y = 236, PF_TABLE_ROW = 36;
final int PF_CHIP_X = 620, PF_CHIP_W = 48, PF_CHIP_GAP = 0, PF_CHIP_H = 28;
final int PF_BAR_X = 824, PF_BAR_W = 236;
final int PF_RULE_FIELD_Y = 460;
final int PF_RULE_W = 138, PF_RULE_GAP = 12;
final int PF_RESET_X = 996, PF_RESET_Y = 414, PF_RESET_W = 64, PF_RESET_H = 26;
final int PF_TEACH_Y = 530, PF_TEACH_W = 112, PF_TEACH_H = 34, PF_TEACH_GAP = 7;

int focusField = 0;
String fieldText = "";

int teachGait = -1;
ArrayList<float[]> teachSamples = new ArrayList<float[]>();
String teachMessage = "";

void initProfiles() {
  File f = new File(sketchPath("profiles.json"));
  if (f.exists()) {
    try {
      JSONObject saved = loadJSONObject(f.getPath());
      JSONArray arr = saved.getJSONArray("profiles");
      for (int i = 0; i < arr.size(); i++) {
        JSONObject o = arr.getJSONObject(i);
        int[] c = o.getJSONArray("channels").getIntArray();
        if (!validChannels(c)) continue;
        Profile p = new Profile(o.getString("name"), c[0], c[1], c[2], c[3]);
        p.heightCm = o.getFloat("heightCm");
        p.stepWidthCm = o.getFloat("stepWidthCm");
        p.stepLengthCm = o.hasKey("stepLengthCm")
        ? o.getFloat("stepLengthCm")
        : 0;
        loadGaitRules(p, o);
        profiles.add(p);
      }
      if (profiles.size() > 0) {
        profile = profiles.get(constrain(saved.getInt("active"), 0, profiles.size() - 1));
      }
    } catch (RuntimeException e) {
      println("Could not read profiles.json: " + e.getMessage());
      profiles.clear();
    }
  }
  if (profiles.size() == 0) {
    profiles.add(new Profile("Green board", 1, 2, 3, 4));
    profiles.add(new Profile("Orange board", 1, 4, 3, 2));
    profile = profiles.get(0);
  }
}

boolean validChannels(int[] c) {
  if (c.length != 4) return false;
  boolean[] seen = new boolean[5];
  for (int v : c) {
    if (v < 1 || v > 4 || seen[v]) return false;
    seen[v] = true;
  }
  return true;
}

void saveProfiles() {
  JSONArray arr = new JSONArray();
  for (Profile p : profiles) {
    JSONObject o = new JSONObject();
    o.setString("name", p.name);
    JSONArray c = new JSONArray();
    for (int v : p.ch) c.append(v);
    o.setJSONArray("channels", c);
    o.setFloat("heightCm", p.heightCm);
    o.setFloat("stepWidthCm", p.stepWidthCm);
    o.setFloat("stepLengthCm", p.stepLengthCm);
    saveGaitRules(p, o);
    arr.append(o);
  }
  JSONObject saved = new JSONObject();
  saved.setInt("active", profiles.indexOf(profile));
  saved.setJSONArray("profiles", arr);
  saveJSONObject(saved, sketchPath("profiles.json"));
}

void loadGaitRules(Profile p, JSONObject o) {
  if (!o.hasKey("gaitRules")) return;
  JSONObject rules = o.getJSONObject("gaitRules");
  p.tipHeelMax = rules.getFloat("tipHeelMax");
  p.heelForeMax = rules.getFloat("heelForeMax");
  p.inToeBalance = rules.getFloat("inToeBalance");
  p.outToeBalance = rules.getFloat("outToeBalance");
  for (int i = 0; i < GAITS.length; i++) {
    if (rules.hasKey(GAITS[i])) p.taught[i] = rules.getJSONArray(GAITS[i]).getFloatArray();
  }
}

void saveGaitRules(Profile p, JSONObject o) {
  JSONObject rules = new JSONObject();
  rules.setFloat("tipHeelMax", p.tipHeelMax);
  rules.setFloat("heelForeMax", p.heelForeMax);
  rules.setFloat("inToeBalance", p.inToeBalance);
  rules.setFloat("outToeBalance", p.outToeBalance);
  for (int i = 0; i < GAITS.length; i++) {
    if (p.taught[i] == null) continue;
    JSONArray values = new JSONArray();
    for (float v : p.taught[i]) values.append(v);
    rules.setJSONArray(GAITS[i], values);
  }
  o.setJSONObject("gaitRules", rules);
}

void selectProfile(Profile p) {
  cancelTeaching();
  profile = p;
  resetGait();
  saveProfiles();
}

synchronized void startTeaching(int gait) {
  teachGait = gait;
  teachSamples.clear();
  teachMessage = "Walk " + GAITS[gait] + " for at least 6 steps, then press Stop.";
}

synchronized void addTeachSample(float heel, float fore, float balance) {
  if (teachGait >= 0) teachSamples.add(new float[] {heel, fore, balance});
}

synchronized void cancelTeaching() {
  teachGait = -1;
  teachSamples.clear();
  teachMessage = "";
}

synchronized void finishTeaching() {
  int gait = teachGait;
  int steps = teachSamples.size();
  teachGait = -1;
  if (steps < MIN_TEACH_STEPS) {
    teachMessage = GAITS[gait] + " not saved: only " + steps + " steps detected, need at least " + MIN_TEACH_STEPS + ".";
    return;
  }

  float[] medians = new float[3];
  for (int f = 0; f < medians.length; f++) {
    float[] values = new float[steps];
    for (int s = 0; s < steps; s++) values[s] = teachSamples.get(s)[f];
    values = sort(values);
    medians[f] = steps % 2 == 1 ? values[steps / 2] : (values[steps / 2 - 1] + values[steps / 2]) / 2;
  }
  profile.taught[gait] = medians;
  teachMessage = GAITS[gait] + " saved from " + steps + " steps. " + updateRulesFromTaught(profile);
  saveProfiles();
}

String updateRulesFromTaught(Profile p) {
  float[][] t = p.taught;
  String warning = "";

  if (t[2] != null) {
    float lowest = lowestTaught(p, 2, 0);
    if (lowest > t[2][0]) p.tipHeelMax = round((t[2][0] + lowest) / 2);
    else if (lowest >= 0) warning += "Tip Toe looks like another gait at the heel. ";
  }
  if (t[1] != null) {
    float lowest = lowestTaught(p, 1, 1);
    if (lowest > t[1][1]) p.heelForeMax = round((t[1][1] + lowest) / 2);
    else if (lowest >= 0) warning += "Heel Walking looks like another gait at the forefoot. ";
  }
  if (t[0] != null && t[3] != null) {
    if (t[3][2] > t[0][2]) p.inToeBalance = (t[0][2] + t[3][2]) / 2;
    else warning += "In-Toe looks the same as Normal for this person. ";
  }
  if (t[0] != null && t[4] != null) {
    if (t[4][2] < t[0][2]) p.outToeBalance = (t[0][2] + t[4][2]) / 2;
    else warning += "Out-Toe looks the same as Normal for this person. ";
  }
  return warning;
}

float lowestTaught(Profile p, int skip, int measure) {
  float lowest = -1;
  for (int i = 0; i < GAITS.length; i++) {
    if (i == skip || p.taught[i] == null) continue;
    if (lowest < 0 || p.taught[i][measure] < lowest) lowest = p.taught[i][measure];
  }
  return lowest;
}

void resetGaitRules() {
  cancelTeaching();
  profile.tipHeelMax = DEFAULT_TIP_HEEL;
  profile.heelForeMax = DEFAULT_HEEL_FORE;
  profile.inToeBalance = DEFAULT_IN_TOE;
  profile.outToeBalance = DEFAULT_OUT_TOE;
  profile.taught = new float[GAITS.length][];
  teachMessage = "Gait rules reset to defaults.";
  saveProfiles();
}

void assignChannel(int region, int channel) {
  int old = profile.ch[region];
  for (int i = 0; i < profile.ch.length; i++) {
    if (profile.ch[i] == channel) profile.ch[i] = old;
  }
  profile.ch[region] = channel;
  resetGait();
  saveProfiles();
}

void addProfile() {
  int n = profiles.size() + 1;
  Profile p = new Profile("Profile " + n, profile.ch[0], profile.ch[1], profile.ch[2], profile.ch[3]);
  p.heightCm = profile.heightCm;
  p.stepLengthCm = profile.stepLengthCm;
  p.stepWidthCm = profile.stepWidthCm;
  profiles.add(p);
  selectProfile(p);
}

void deleteProfile() {
  if (profiles.size() <= 1) return;
  int i = profiles.indexOf(profile);
  profiles.remove(i);
  selectProfile(profiles.get(min(i, profiles.size() - 1)));
}

void drawProfileScreen() {
  pageTitle("Profiles", "");

  int listH = profiles.size() * PF_ROW_H + 8;
  card(PF_LIST_X, PF_LIST_Y - 4, PF_LIST_W, listH);
  for (int i = 0; i < profiles.size(); i++) {
    Profile p = profiles.get(i);
    int y = PF_LIST_Y + i * PF_ROW_H;
    boolean over = hot(PF_LIST_X, y, PF_LIST_W, PF_ROW_H);
    if (over) {
      noStroke();
      fill(0, 7);
      rect(PF_LIST_X + 4, y, PF_LIST_W - 8, PF_ROW_H, 8);
    }
    noStroke();
    fill(p == profile ? C_BLUE : C_SECOND);
    ellipse(PF_LIST_X + 26, y + PF_ROW_H / 2, 28, 28);
    tx(13, true, color(255), CENTER, CENTER);
    text(p.name.substring(0, 1).toUpperCase(), PF_LIST_X + 26, y + PF_ROW_H / 2 - 1);
    tx(14, p == profile, C_LABEL, LEFT, CENTER);
    text(p.name, PF_LIST_X + 48, y + PF_ROW_H / 2 - 1);
    if (p == profile) {
      stroke(C_BLUE); strokeWeight(2.2); noFill();
      int cx = PF_LIST_X + PF_LIST_W - 26, cy = y + PF_ROW_H / 2;
      line(cx - 5, cy, cx - 1, cy + 4);
      line(cx - 1, cy + 4, cx + 6, cy - 5);
    }
    if (i < profiles.size() - 1) {
      stroke(C_SEP); strokeWeight(1);
      line(PF_LIST_X + 48, y + PF_ROW_H, PF_LIST_X + PF_LIST_W, y + PF_ROW_H);
    }
  }

  int by = pfButtonY();
  pillButton("New", PF_LIST_X, by, PF_LIST_BTN_W, PF_LIST_BTN_H, C_BLUE, false);
  pillButton("Delete", PF_LIST_X + PF_LIST_W - PF_LIST_BTN_W, by, PF_LIST_BTN_W, PF_LIST_BTN_H, C_RED, false);

  tx(12, false, C_SECOND, LEFT, TOP);
  textLeading(17);
  text("Each person or board can have its own wiring, measurements and gait rules.",
       PF_LIST_X + 4, by + PF_LIST_BTN_H + 14, PF_LIST_W - 8, 60);

  card(PF_CARD_X, 86, PF_CARD_W, 84);
  drawField("Name", 1, profile.name, PF_X, PF_NUM_Y, PF_NAME_W);
  drawField("Height (cm)", 2, nf(profile.heightCm, 0, 0), PF_HEIGHT_X, PF_NUM_Y, PF_HEIGHT_W);
  drawField("Step width (cm)", 3,
            profile.stepWidthCm > 0 ? nf(profile.stepWidthCm, 0, 1) : "", PF_WIDTH_X, PF_NUM_Y, PF_NUM_W);
  drawField("Step length (cm)", 4,
            profile.stepLengthCm > 0 ? nf(profile.stepLengthCm, 0, 1) : "", PF_LENGTH_X, PF_NUM_Y, PF_NUM_W);

  card(PF_CARD_X, 182, PF_CARD_W, 212);
  tx(15, true, C_LABEL, LEFT, TOP);
  text("Sensor Wiring", PF_X, 194);
  tx(12, false, C_SECOND, RIGHT, TOP);
  text("Press one sensor and watch which channel rises", PF_CARD_X + PF_CARD_W - 16, 197);

  tx(11, false, C_SECOND, CENTER, BOTTOM);
  for (int c = 0; c < 4; c++) {
    text(int(rawCh[c]), chipX(c) + PF_CHIP_W / 2, PF_TABLE_Y - 3);
  }

  String[] channels = {"A0", "A1", "A2", "A3"};
  int segW = 4 * PF_CHIP_W + 3 * PF_CHIP_GAP;
  for (int r = 0; r < REGIONS.length; r++) {
    int y = PF_TABLE_Y + r * PF_TABLE_ROW;
    tx(13, false, C_LABEL, LEFT, CENTER);
    text(REGIONS[r], PF_X, y + PF_CHIP_H / 2 - 1);

    segmented(PF_CHIP_X, y, segW, PF_CHIP_H, channels, profile.ch[r] - 1, "chan" + r);

    float v = rawCh[profile.ch[r] - 1];
    noStroke();
    fill(C_SEP);
    rect(PF_BAR_X, y + 9, PF_BAR_W, 10, 5);
    fill(C_BLUE);
    rect(PF_BAR_X, y + 9, map(constrain(v, 0, 1023), 0, 1023, 0, PF_BAR_W), 10, 5);
  }

  card(PF_CARD_X, 406, PF_CARD_W, 272);
  drawGaitRules();
}

int pfButtonY() {
  return PF_LIST_Y + profiles.size() * PF_ROW_H + 16;
}

int ruleX(int i) {
  return PF_X + i * (PF_RULE_W + PF_RULE_GAP);
}

int teachX(int i) {
  return PF_X + i * (PF_TEACH_W + PF_TEACH_GAP);
}

void drawGaitRules() {
  tx(15, true, C_LABEL, LEFT, TOP);
  text("Gait Rules", PF_X, 418);
  pillButton("Reset", PF_RESET_X, PF_RESET_Y, PF_RESET_W, PF_RESET_H, C_RED, false);

  drawField("Tip Toe: heel below", 5, nf(profile.tipHeelMax, 0, 0), ruleX(0), PF_RULE_FIELD_Y, PF_RULE_W);
  drawField("Heel: forefoot below", 6, nf(profile.heelForeMax, 0, 0), ruleX(1), PF_RULE_FIELD_Y, PF_RULE_W);
  drawField("In-Toe: balance above", 7, nf(profile.inToeBalance, 0, 2), ruleX(2), PF_RULE_FIELD_Y, PF_RULE_W);
  drawField("Out-Toe: balance below", 8, nf(profile.outToeBalance, 0, 2), ruleX(3), PF_RULE_FIELD_Y, PF_RULE_W);

  tx(13, true, C_LABEL, LEFT, TOP);
  text("Teach a gait", PF_X, PF_TEACH_Y - 21);

  for (int i = 0; i < GAITS.length; i++) {
    boolean teaching = teachGait == i;
    int x = teachX(i);
    boolean over = hot(x, PF_TEACH_Y, PF_TEACH_W, PF_TEACH_H);
    noStroke();
    fill(teaching ? C_RED : GAIT_COLORS[i], teaching ? 255 : (over ? 60 : 36));
    rect(x, PF_TEACH_Y, PF_TEACH_W, PF_TEACH_H, 9);
    tx(12, true, teaching ? color(255) : color(C_LABEL), CENTER, CENTER);
    text(teaching ? "Stop (" + teachSamples.size() + ")" : GAITS[i], x + PF_TEACH_W / 2, PF_TEACH_Y + PF_TEACH_H / 2 - 1);
    if (profile.taught[i] != null) {
      noStroke();
      fill(GAIT_COLORS[i]);
      ellipse(x + PF_TEACH_W - 9, PF_TEACH_Y + 9, 7, 7);
    }
  }

  tx(12, false, C_SECOND, LEFT, TOP);
  textLeading(17);
  String hint = teachMessage.length() > 0 ? teachMessage
    : "If gaits are wrong for someone, teach each gait, starting with Normal. A dot means taught.";
  text(hint, PF_X, PF_TEACH_Y + PF_TEACH_H + 12, PF_CARD_W - 32, 38);

  if (lastGait.length() > 0) {
    tx(12, true, C_LABEL, LEFT, TOP);
    text("Last step: " + lastGait, PF_X, 650);
    tx(12, false, C_SECOND, RIGHT, TOP);
    text("heel " + round(lastHeelPeak) + "   forefoot " + round(lastForePeak) + "   balance " + nf(lastBalance, 0, 2),
         PF_CARD_X + PF_CARD_W - 16, 650);
  }
}

int chipX(int c) {
  return PF_CHIP_X + c * (PF_CHIP_W + PF_CHIP_GAP);
}

void drawField(String label, int id, String value, int x, int y, int w) {
  tx(11, false, C_SECOND, LEFT, BOTTOM);
  text(label, x, y - 3);

  boolean focused = focusField == id;
  hot(x, y, w, PF_FIELD_H);
  noStroke();
  fill(focused ? color(255) : C_BG);
  rect(x, y, w, PF_FIELD_H, 8);
  if (focused) {
    noFill();
    stroke(C_BLUE); strokeWeight(2);
    rect(x, y, w, PF_FIELD_H, 8);
  }

  tx(14, false, C_LABEL, LEFT, CENTER);
  text(focused ? fieldText + "|" : value, x + 9, y + PF_FIELD_H / 2 - 1);
}

boolean mouseOver(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void profileClick() {

  commitField();

  if (mouseOver(ruleX(0), PF_RULE_FIELD_Y, PF_RULE_W, PF_FIELD_H)) {
    focusOn(5, nf(profile.tipHeelMax, 0, 0));
    return;
  }
  if (mouseOver(ruleX(1), PF_RULE_FIELD_Y, PF_RULE_W, PF_FIELD_H)) {
    focusOn(6, nf(profile.heelForeMax, 0, 0));
    return;
  }
  if (mouseOver(ruleX(2), PF_RULE_FIELD_Y, PF_RULE_W, PF_FIELD_H)) {
    focusOn(7, nf(profile.inToeBalance, 0, 2));
    return;
  }
  if (mouseOver(ruleX(3), PF_RULE_FIELD_Y, PF_RULE_W, PF_FIELD_H)) {
    focusOn(8, nf(profile.outToeBalance, 0, 2));
    return;
  }
  if (mouseOver(PF_RESET_X, PF_RESET_Y, PF_RESET_W, PF_RESET_H)) {
    resetGaitRules();
    return;
  }

  for (int i = 0; i < GAITS.length; i++) {
    if (mouseOver(teachX(i), PF_TEACH_Y, PF_TEACH_W, PF_TEACH_H)) {
      if (teachGait == i) finishTeaching();
      else startTeaching(i);
      return;
    }
  }

  for (int i = 0; i < profiles.size(); i++) {
    if (mouseOver(PF_LIST_X, PF_LIST_Y + i * PF_ROW_H, PF_LIST_W, PF_ROW_H)) {
      selectProfile(profiles.get(i));
      return;
    }
  }

  int by = pfButtonY();
  if (mouseOver(PF_LIST_X, by, PF_LIST_BTN_W, PF_LIST_BTN_H)) {
    addProfile();
    return;
  }
  if (mouseOver(PF_LIST_X + PF_LIST_W - PF_LIST_BTN_W, by, PF_LIST_BTN_W, PF_LIST_BTN_H)) {
    deleteProfile();
    return;
  }

  if (mouseOver(PF_X, PF_NUM_Y, PF_NAME_W, PF_FIELD_H)) {
    focusOn(1, profile.name);
    return;
  }
  if (mouseOver(PF_HEIGHT_X, PF_NUM_Y, PF_HEIGHT_W, PF_FIELD_H)) {
    focusOn(2, nf(profile.heightCm, 0, 0));
    return;
  }
  if (mouseOver(PF_WIDTH_X, PF_NUM_Y, PF_NUM_W, PF_FIELD_H)) {
    focusOn(3, profile.stepWidthCm > 0 ? nf(profile.stepWidthCm, 0, 1) : "");
    return;
  }
  if (mouseOver(PF_LENGTH_X, PF_NUM_Y, PF_NUM_W, PF_FIELD_H)) {
    focusOn(4, profile.stepLengthCm > 0 ? nf(profile.stepLengthCm, 0, 1) : "");
    return;
  }

  int segW = 4 * PF_CHIP_W + 3 * PF_CHIP_GAP;
  for (int r = 0; r < REGIONS.length; r++) {
    int c = segmentHit(PF_CHIP_X, PF_TABLE_Y + r * PF_TABLE_ROW, segW, PF_CHIP_H, 4);
    if (c >= 0) {
      assignChannel(r, c + 1);
      return;
    }
  }
}

void focusOn(int id, String value) {
  focusField = id;
  fieldText = value;
}

void commitField() {

  if (focusField == 1 && trim(fieldText).length() > 0) {

    profile.name = trim(fieldText);
  }

  else if (focusField == 2) {

    float v = float(fieldText);

    if (v >= 50 && v <= 250) {
      profile.heightCm = v;
    }
  }

  else if (focusField == 3) {

    float v = float(fieldText);

    profile.stepWidthCm =
      v > 0 && v <= 100 ? v : 0;
  }

  else if (focusField == 4) {

    float v = float(fieldText);

    profile.stepLengthCm =
      v > 0 && v <= 200 ? v : 0;
  }

  else if (focusField == 5 || focusField == 6) {

    float v = float(fieldText);

    if (v >= 0 && v <= 1023) {
      if (focusField == 5) profile.tipHeelMax = v;
      else profile.heelForeMax = v;
    }
  }

  else if (focusField == 7 || focusField == 8) {

    float v = float(fieldText);

    if (v >= -1 && v <= 1) {
      if (focusField == 7) profile.inToeBalance = v;
      else profile.outToeBalance = v;
    }
  }

  if (focusField != 0) {
    saveProfiles();
  }

  focusField = 0;
}

void profileKey() {

  if (key == ESC) key = 0;

  if (focusField == 0 || key == CODED) return;

  if (key == ENTER || key == RETURN) {

    commitField();
  }

  else if (key == BACKSPACE || key == DELETE) {

    if (fieldText.length() > 0) {
      fieldText =
        fieldText.substring(0, fieldText.length() - 1);
    }
  }

  else if (key >= ' ' && key != 127) {

    boolean numeric = focusField != 1;

    boolean allowed = numeric
      ? (key >= '0' && key <= '9') || key == '.' || (key == '-' && focusField >= 7)
      : fieldText.length() < 24;

    if (allowed) {
      fieldText += key;
    }
  }
}
