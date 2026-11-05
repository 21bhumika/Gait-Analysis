PrintWriter recording = null;
int recordStart = 0;

final int REC_W = 96;
final int REC_H = 30;
final int REC_Y = 34;

synchronized void startRecording() {
  String stamp = year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "_"
               + nf(hour(), 2) + "-" + nf(minute(), 2) + "-" + nf(second(), 2);
  recording = createWriter("recordings/session_" + stamp + ".txt");
  recording.println("time_ms,MF,LF,MM,HEEL,ax,ay,az,motion,activitySec,gx,gy,gz,board_ms,MFP_pct");
  recordStart = millis();
  resetGait();
}

synchronized void stopRecording() {
  if (recording == null) return;
  recording.close();
  recording = null;
}

synchronized void recordSample() {
  if (recording == null) return;
  recording.println((millis() - recordStart) + ","
    + int(mfBuf[BUF-1]) + "," + int(lfBuf[BUF-1]) + ","
    + int(mmBuf[BUF-1]) + "," + int(heelBuf[BUF-1]) + ","
    + ax + "," + ay + "," + az + ","
    + (inMotion ? 1 : 0) + "," + activitySec + ","
    + gyroX + "," + gyroY + "," + gyroZ + "," + boardMs
    + "," + (sessionTotalSum > 0
    ? nf(100.0 * sessionMedialSum / sessionTotalSum, 0, 2)
    : "0"));
  recording.flush();
}

void drawRecordBtn() {
  int x = width - 24 - REC_W;
  boolean active = recording != null;
  boolean over = hot(x, REC_Y, REC_W, REC_H);

  noStroke();
  fill(C_RED, active ? 255 : (over ? 50 : 30));
  rect(x, REC_Y, REC_W, REC_H, REC_H / 2.0);

  String label = "Record";
  if (active) {
    int s = (millis() - recordStart) / 1000;
    label = nf(s / 60, 2) + ":" + nf(s % 60, 2);
  }
  fill(active ? color(255) : C_RED);
  ellipse(x + 18, REC_Y + REC_H / 2, 9, 9);
  tx(14, true, active ? color(255) : C_RED, LEFT, CENTER);
  text(label, x + 30, REC_Y + REC_H / 2 - 1);
}

boolean recordBtnHit() {
  int x = width - 24 - REC_W;
  return mouseX >= x && mouseX <= x + REC_W && mouseY >= REC_Y && mouseY <= REC_Y + REC_H;
}

void toggleRecording() {
  if (recording == null) startRecording();
  else stopRecording();
}
