PrintWriter recording = null;
int recordStart = 0;

final int REC_W = 96;
final int REC_H = 20;
final int REC_Y = 2;

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
  int x = width - PAD - REC_W;
  boolean active = recording != null;

  if (active) {
    fill(210, 40, 40); stroke(160, 20, 20);
  } else {
    fill(230); stroke(180);
  }
  strokeWeight(1);
  rect(x, REC_Y, REC_W, REC_H, 4);

  String label = "Record";
  if (active) {
    int s = (millis() - recordStart) / 1000;
    label = "Stop  " + nf(s / 60, 2) + ":" + nf(s % 60, 2);
  }
  fill(active ? 255 : 60); textAlign(CENTER, CENTER); textSize(11);
  text(label, x + REC_W / 2, REC_Y + REC_H / 2);
}

boolean recordBtnHit() {
  int x = width - PAD - REC_W;
  return mouseX >= x && mouseX <= x + REC_W && mouseY >= REC_Y && mouseY <= REC_Y + REC_H;
}

void toggleRecording() {
  if (recording == null) startRecording();
  else stopRecording();
}
