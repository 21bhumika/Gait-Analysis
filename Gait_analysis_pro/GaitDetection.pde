// Step and gait detection
// One contact = the instrumented foot landing, then lifting.
// Thresholds were chosen from the walking sessions in recordings/.

final float FOOT_ON  = 300, FOOT_OFF = 150;   // MF, LF, MM
final float HEEL_ON  = 650, HEEL_OFF = 560;   // heel stays loaded during swing

final int MIN_CONTACT_MS    = 350;
final int GAIT_PAUSE_MS     = 3000;
final int STEPS_PER_CONTACT = 2;              // sensors are on one foot only
final int MIN_VOTES         = 3;

final float IN_TOE_BALANCE  =  0.11;
final float OUT_TOE_BALANCE = -0.08;
// Medial Force Percentage
float sessionMedialSum = 0;
float sessionTotalSum = 0;

boolean footArmed = false;   // stays false until the first lift, so standing isn't a step
boolean footDown  = false;
int landTime = 0;
float peakMF = 0, peakLF = 0, peakMM = 0, peakHeel = 0;

String[] gaitVotes = new String[5];
int voteCount = 0;

// Rule of thumb: one step is about 0.415 x height, and a stride is two steps.
final float STRIDE_PER_HEIGHT = 0.83;

final String[] GAITS = {"Normal Gait", "Heel Walking", "Tip Toe", "In-Toe", "Out-Toe"};
int[] gaitMs = new int[GAITS.length];
int lastContactGait = -1;
float strideMs = 0;
int walkStart = 0;

synchronized void resetGait() {
  footArmed = false;
  footDown  = false;
  voteCount = 0;
  stepCount = 0;
  cadence   = 0;
  gaitLabel = "—";
  strideMs  = 0;
  lastContactGait = -1;
  gaitMs = new int[GAITS.length];
  resetStride();
  sessionMedialSum = 0;
  sessionTotalSum = 0;
}

synchronized void updateGait(int now) {
  float mf = mfBuf[BUF-1], lf = lfBuf[BUF-1], mm = mmBuf[BUF-1], heel = heelBuf[BUF-1];
  boolean on  = mf > FOOT_ON  || lf > FOOT_ON  || mm > FOOT_ON  || heel > HEEL_ON;
  boolean off = mf < FOOT_OFF && lf < FOOT_OFF && mm < FOOT_OFF && heel < HEEL_OFF;

  if (!footArmed) {
    footArmed = off;
    return;
  }

  if (!footDown && on) landFoot(now);

  if (footDown) {

  peakMF   = max(peakMF, mf);
  peakLF   = max(peakLF, lf);
  peakMM   = max(peakMM, mm);
  peakHeel = max(peakHeel, heel);

  // Accumulate FSR readings during stance
  if (!off) {

    sessionMedialSum += mf + mm;

    sessionTotalSum +=
      mf + lf + mm + heel;
  }

  if (off && now - landTime >= MIN_CONTACT_MS) {
    liftFoot(now);
  }
}
}

void landFoot(int now) {
  int gap = now - landTime;
  if (stepCount > 0 && gap < GAIT_PAUSE_MS) {
    float instant = STEPS_PER_CONTACT * 60000.0 / gap;
    cadence = cadence == 0 ? instant : 0.7 * cadence + 0.3 * instant;
    strideMs = strideMs == 0 ? gap : 0.7 * strideMs + 0.3 * gap;
    if (lastContactGait >= 0) gaitMs[lastContactGait] += gap;
  } else {
    cadence = 0;
    strideMs = 0;
    voteCount = 0;
    walkStart = now;
  }
  lastContactGait = -1;
  stepCount += STEPS_PER_CONTACT;
  landTime = now;
  footDown = true;
  peakMF = peakLF = peakMM = peakHeel = 0;
}

void liftFoot(int now) {
  footDown = false;
  if (now - landTime >= GAIT_PAUSE_MS) return;   // standing still, not a step
  String gait = classifyContact();
  addGaitVote(gait);
  for (int i = 0; i < GAITS.length; i++) {
    if (GAITS[i].equals(gait)) lastContactGait = i;
  }
}

String classifyContact() {
  if (peakHeel < 300) return "Tip Toe";
  if (peakMF < 100 && peakMM < 100 && peakLF < 500) return "Heel Walking";

  float balance = (peakMF - peakLF) / max(peakMF + peakLF, 1);
  if (balance > IN_TOE_BALANCE)  return "In-Toe";
  if (balance < OUT_TOE_BALANCE) return "Out-Toe";
  return "Normal Gait";
}

void addGaitVote(String gait) {
  arrayCopy(gaitVotes, 1, gaitVotes, 0, gaitVotes.length - 1);
  gaitVotes[gaitVotes.length - 1] = gait;
  voteCount = min(voteCount + 1, gaitVotes.length);
  if (voteCount < MIN_VOTES) return;

  // >= so a tie goes to the more recent gait
  int bestCount = 0;
  for (int i = gaitVotes.length - voteCount; i < gaitVotes.length; i++) {
    int n = 0;
    for (int j = gaitVotes.length - voteCount; j < gaitVotes.length; j++) {
      if (gaitVotes[j].equals(gaitVotes[i])) n++;
    }
    if (n >= bestCount) {
      bestCount = n;
      gaitLabel = gaitVotes[i];
    }
  }
}

boolean walkingNow() {
  return stepCount > 0 && millis() - landTime <= GAIT_PAUSE_MS;
}

int motionMs() {
  if (stepCount == 0) return 0;
  return (walkingNow() ? millis() : landTime) - walkStart;
}

String formatTime(int ms) {
  int s = ms / 1000;
  return nf(s / 60, 2) + ":" + nf(s % 60, 2);
}

String cadenceText() {
  if (cadence == 0 || !walkingNow()) return "— steps/min";
  return round(cadence) + " steps/min";
}

String strideTimeText() {
  if (strideMs == 0 || !walkingNow()) return "— s";
  return nf(strideMs / 1000, 0, 2) + " s";
}

float strideLengthM() {

  // Priority 1: measured step length
  if (profile.stepLengthCm > 0) {
    return 2.0 * profile.stepLengthCm / 100.0;
  }

  // Priority 2: inertial estimate
  if (gyroStrideM > 0) {
    return gyroStrideM;
  }

  // Fallback: anthropometric estimate
  return STRIDE_PER_HEIGHT * profile.heightCm / 100.0;
}

String strideLengthText() {
  return "~" + nf(strideLengthM(), 0, 2) + " m";
}

String speedText() {
  if (strideMs == 0 || !walkingNow()) return "— m/s";
  return "~" + nf(strideLengthM() / (strideMs / 1000), 0, 2) + " m/s";
}

String stepWidthText() {
  if (profile.stepWidthCm > 0) return nf(profile.stepWidthCm, 0, 1) + " cm";
  return "Needs 2 feet";
}

String stepLengthText() {

  if (profile.stepLengthCm <= 0) {
    return "— cm";
  }

  return nf(profile.stepLengthCm, 0, 1) + " cm";
}

String mfpText() {

  if (sessionTotalSum <= 0) {
    return "— %";
  }

  float mfp =
    100.0 * sessionMedialSum / sessionTotalSum;

  return nf(mfp, 0, 1) + "%";
}
