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

final int PF_LIST_X = 30, PF_LIST_Y = 80, PF_LIST_W = 260, PF_ROW_H = 36;
final int PF_X = 330, PF_FIELD_H = 30;
final int PF_NAME_Y = 90, PF_NUM_Y = 160;
final int PF_NUM_W = 150, PF_NUM2_X = 500;
final int PF_TABLE_Y = 260, PF_TABLE_ROW = 56;
final int PF_CHIP_X = 510, PF_CHIP_W = 48, PF_CHIP_GAP = 8, PF_CHIP_H = 32;
final int PF_BAR_X = 760, PF_BAR_W = 300;
final int PF_RULES_Y = 498, PF_RULE_FIELD_Y = 532, PF_TEACH_Y = 582;
final int PF_RULE_W = 150, PF_RULE_GAP = 16, PF_TEACH_W = 134, PF_TEACH_H = 30;

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
  background(242, 242, 242);

  fill(30); textAlign(LEFT, TOP); textSize(20);
  text("Sensor Profiles", PF_LIST_X + 90, 22);
  drawPfButton("← Back", PF_LIST_X, 20, 72, 28, false);

  for (int i = 0; i < profiles.size(); i++) {
    Profile p = profiles.get(i);
    drawPfButton(p.name, PF_LIST_X, PF_LIST_Y + i * PF_ROW_H, PF_LIST_W, PF_ROW_H - 6, p == profile);
  }
  int by = PF_LIST_Y + profiles.size() * PF_ROW_H + 4;
  drawPfButton("+ New", PF_LIST_X, by, 125, 28, false);
  drawPfButton("Delete", PF_LIST_X + 135, by, 125, 28, false);

  drawField("Name", 1, profile.name, PF_X, PF_NAME_Y, PF_NUM2_X + PF_NUM_W - PF_X);
  drawField("Height (cm)", 2, nf(profile.heightCm, 0, 0), PF_X, PF_NUM_Y, PF_NUM_W);
  drawField("Step width (cm, measured)", 3,
            profile.stepWidthCm > 0 ? nf(profile.stepWidthCm, 0, 1) : "", PF_NUM2_X, PF_NUM_Y, PF_NUM_W);
  drawField(
  "Step length (cm)",
  4,
  profile.stepLengthCm > 0
    ? nf(profile.stepLengthCm, 0, 1)
    : "",
  680,
  PF_NUM_Y,
  150
  );
  fill(110); textAlign(LEFT, TOP); textSize(11);
  text("Wiring: press one sensor at a time and watch which channel rises, then pick it for that region.",
       PF_X, PF_NUM_Y + 44);

  textAlign(CENTER, BOTTOM); textSize(10); fill(90);
  for (int c = 0; c < 4; c++) {
    text(int(rawCh[c]), chipX(c) + PF_CHIP_W / 2, PF_TABLE_Y - 4);
  }

  for (int r = 0; r < REGIONS.length; r++) {
    int y = PF_TABLE_Y + r * PF_TABLE_ROW;
    fill(40); textAlign(LEFT, CENTER); textSize(13);
    text(REGIONS[r], PF_X, y + PF_CHIP_H / 2);

    for (int c = 0; c < 4; c++) {
      drawPfButton("A" + c, chipX(c), y, PF_CHIP_W, PF_CHIP_H, profile.ch[r] == c + 1);
    }

    float v = rawCh[profile.ch[r] - 1];
    noStroke(); fill(225);
    rect(PF_BAR_X, y + 8, PF_BAR_W, 16, 3);
    fill(70, 120, 220);
    rect(PF_BAR_X, y + 8, map(constrain(v, 0, 1023), 0, 1023, 0, PF_BAR_W), 16, 3);
  }

  drawGaitRules();
}

int ruleX(int i) {
  return PF_X + i * (PF_RULE_W + PF_RULE_GAP);
}

int teachX(int i) {
  return PF_X + i * (PF_TEACH_W + 8);
}

void drawGaitRules() {
  stroke(210); strokeWeight(1);
  line(PF_X, PF_RULES_Y - 8, width - 30, PF_RULES_Y - 8);

  fill(40); textAlign(LEFT, TOP); textSize(13);
  text("Gait rules for this profile", PF_X, PF_RULES_Y);

  drawField("Tip Toe: heel peak below", 5, nf(profile.tipHeelMax, 0, 0), ruleX(0), PF_RULE_FIELD_Y, PF_RULE_W);
  drawField("Heel: forefoot peak below", 6, nf(profile.heelForeMax, 0, 0), ruleX(1), PF_RULE_FIELD_Y, PF_RULE_W);
  drawField("In-Toe: balance above", 7, nf(profile.inToeBalance, 0, 2), ruleX(2), PF_RULE_FIELD_Y, PF_RULE_W);
  drawField("Out-Toe: balance below", 8, nf(profile.outToeBalance, 0, 2), ruleX(3), PF_RULE_FIELD_Y, PF_RULE_W);
  drawPfButton("Reset rules", ruleX(4) - 6, PF_RULE_FIELD_Y, 76, PF_FIELD_H, false);

  for (int i = 0; i < GAITS.length; i++) {
    boolean teaching = teachGait == i;
    String label = teaching ? "Stop (" + teachSamples.size() + " steps)" : "Teach " + GAITS[i];
    drawPfButton(label, teachX(i), PF_TEACH_Y, PF_TEACH_W, PF_TEACH_H, teaching);
    if (profile.taught[i] != null) {
      fill(50, 130, 70); textAlign(CENTER, TOP); textSize(10);
      text("taught", teachX(i) + PF_TEACH_W / 2, PF_TEACH_Y + PF_TEACH_H + 2);
    }
  }

  fill(90); textAlign(LEFT, TOP); textSize(11);
  String hint = teachMessage.length() > 0 ? teachMessage
    : "If gaits are wrong for someone, teach each gait, starting with Normal. Or type the limits above.";
  text(hint, PF_X, PF_TEACH_Y + PF_TEACH_H + 18);

  if (lastGait.length() > 0) {
    text("Last step:  heel " + round(lastHeelPeak) + "   forefoot " + round(lastForePeak)
         + "   balance " + nf(lastBalance, 0, 2) + "   =  " + lastGait,
         PF_X, PF_TEACH_Y + PF_TEACH_H + 36);
  }
}

int chipX(int c) {
  return PF_CHIP_X + c * (PF_CHIP_W + PF_CHIP_GAP);
}

void drawPfButton(String label, int x, int y, int w, int h, boolean active) {
  if (active) {
    fill(70, 120, 220); stroke(50, 95, 190);
  } else {
    fill(mouseOver(x, y, w, h) ? 225 : 255); stroke(180);
  }
  strokeWeight(1);
  rect(x, y, w, h, 5);
  fill(active ? 255 : 50); textAlign(CENTER, CENTER); textSize(12);
  text(label, x + w / 2, y + h / 2);
}

void drawField(String label, int id, String value, int x, int y, int w) {
  fill(90); textAlign(LEFT, BOTTOM); textSize(11);
  text(label, x, y - 3);

  boolean focused = focusField == id;
  fill(255); stroke(focused ? color(70, 120, 220) : color(180)); strokeWeight(focused ? 2 : 1);
  rect(x, y, w, PF_FIELD_H, 4);

  fill(30); textAlign(LEFT, CENTER); textSize(13);
  text(focused ? fieldText + "|" : value, x + 8, y + PF_FIELD_H / 2);
}

boolean mouseOver(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void profileClick() {

  commitField();

  if (mouseOver(PF_LIST_X, 20, 72, 28)) {
    cancelTeaching();
    screen = 1;
    return;
  }

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
  if (mouseOver(ruleX(4) - 6, PF_RULE_FIELD_Y, 76, PF_FIELD_H)) {
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

    if (mouseOver(
      PF_LIST_X,
      PF_LIST_Y + i * PF_ROW_H,
      PF_LIST_W,
      PF_ROW_H - 6)) {

      selectProfile(profiles.get(i));
      return;
    }
  }

  int by = PF_LIST_Y + profiles.size() * PF_ROW_H + 4;

  if (mouseOver(PF_LIST_X, by, 125, 28)) {
    addProfile();
    return;
  }

  if (mouseOver(PF_LIST_X + 135, by, 125, 28)) {
    deleteProfile();
    return;
  }

  if (mouseOver(
    PF_X, PF_NAME_Y,
    PF_NUM2_X + PF_NUM_W - PF_X,
    PF_FIELD_H)) {

    focusOn(1, profile.name);
    return;
  }

  if (mouseOver(PF_X, PF_NUM_Y, PF_NUM_W, PF_FIELD_H)) {

    focusOn(2, nf(profile.heightCm, 0, 0));
    return;
  }

  if (mouseOver(
    PF_NUM2_X, PF_NUM_Y,
    PF_NUM_W, PF_FIELD_H)) {

    focusOn(
      3,
      profile.stepWidthCm > 0
        ? nf(profile.stepWidthCm, 0, 1)
        : ""
    );

    return;
  }

  if (mouseOver(680, PF_NUM_Y, 150, PF_FIELD_H)) {

    focusOn(
      4,
      profile.stepLengthCm > 0
        ? nf(profile.stepLengthCm, 0, 1)
        : ""
    );

    return;
  }

  for (int r = 0; r < REGIONS.length; r++) {

    for (int c = 0; c < 4; c++) {

      if (mouseOver(
        chipX(c),
        PF_TABLE_Y + r * PF_TABLE_ROW,
        PF_CHIP_W,
        PF_CHIP_H)) {

        assignChannel(r, c + 1);
        return;
      }
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
