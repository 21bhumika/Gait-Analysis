// Sensor profiles
// Each board can be wired differently, so a profile maps every foot region to an
// Arduino channel. Saved to profiles.json in the sketch folder.

class Profile {
  String name;
  int[] ch = {1, 2, 3, 4};   // MF, LF, MM, HEEL -> column in the DATA line (1 = A0)
  float heightCm = 170;
  float stepWidthCm = 0;     // 0 = not entered
  float stepLengthCm = 0;
  Profile(String name, int mf, int lf, int mm, int heel) {
    this.name = name;
    ch = new int[] {mf, lf, mm, heel};
  }
}

final String[] REGIONS = {"Medial Forefoot (MF)", "Lateral Forefoot (LF)", "Medial Mid-foot (MM)", "Heel"};

ArrayList<Profile> profiles = new ArrayList<Profile>();
Profile profile;
float[] rawCh = new float[4];

// Profile screen layout
final int PF_LIST_X = 30, PF_LIST_Y = 80, PF_LIST_W = 260, PF_ROW_H = 36;
final int PF_X = 330, PF_FIELD_H = 30;
final int PF_NAME_Y = 90, PF_NUM_Y = 160;
final int PF_NUM_W = 150, PF_NUM2_X = 500;
final int PF_TABLE_Y = 260, PF_TABLE_ROW = 56;
final int PF_CHIP_X = 510, PF_CHIP_W = 48, PF_CHIP_GAP = 8, PF_CHIP_H = 32;
final int PF_BAR_X = 760, PF_BAR_W = 300;

int focusField = 0;   // 0=none 1=name 2=height 3=step width
String fieldText = "";

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
    arr.append(o);
  }
  JSONObject saved = new JSONObject();
  saved.setInt("active", profiles.indexOf(profile));
  saved.setJSONArray("profiles", arr);
  saveJSONObject(saved, sketchPath("profiles.json"));
}

void selectProfile(Profile p) {
  profile = p;
  resetGait();
  saveProfiles();
}

// Keeps the mapping one-to-one: the region already on this channel takes the old one.
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

// Drawing
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

  // Live reading above each channel column
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

// Input
void profileClick() {

  commitField();

  // Back button
  if (mouseOver(PF_LIST_X, 20, 72, 28)) {
    screen = 1;
    return;
  }

  // Select profile
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

  // Add profile
  if (mouseOver(PF_LIST_X, by, 125, 28)) {
    addProfile();
    return;
  }

  // Delete profile
  if (mouseOver(PF_LIST_X + 135, by, 125, 28)) {
    deleteProfile();
    return;
  }

  // Profile name
  if (mouseOver(
    PF_X, PF_NAME_Y,
    PF_NUM2_X + PF_NUM_W - PF_X,
    PF_FIELD_H)) {

    focusOn(1, profile.name);
    return;
  }

  // Height
  if (mouseOver(PF_X, PF_NUM_Y, PF_NUM_W, PF_FIELD_H)) {

    focusOn(2, nf(profile.heightCm, 0, 0));
    return;
  }

  // Step width
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

  // Step length
  if (mouseOver(680, PF_NUM_Y, 150, PF_FIELD_H)) {

    focusOn(
      4,
      profile.stepLengthCm > 0
        ? nf(profile.stepLengthCm, 0, 1)
        : ""
    );

    return;
  }

  // Assign sensor channels
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
      ? (key >= '0' && key <= '9') || key == '.'
      : fieldText.length() < 24;

    if (allowed) {
      fieldText += key;
    }
  }
}
