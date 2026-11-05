PImage leftFootImg, rightFootImg;
PImage image;

final float HM_MIN  = 400;
final float HM_STEP = 100;
final int   HM_MAX_LEVELS = 7;

color[] hmColors = {
  color(255, 235, 0),
  color(255, 165, 0),
  color(255, 110, 0),
  color(235, 40, 0),
  color(190, 0, 0),
  color(140, 0, 0),
  color(90, 0, 0)
};

/* positions for green board
  {0.30, 0.33},   // MF   medial forefoot
  {0.72, 0.41},   // LF   lateral forefoot
  {0.27, 0.54},   // MM   medial midfoot
  {0.50, 0.86}    // HEEL
*/

/* positions for orange board
 {0.70, 0.28},   // MF   medial forefoot
  {0.32, 0.41},   // LF   lateral forefoot
  {0.67, 0.50},   // MM   medial midfoot
  {0.50, 0.86},   // HEEL
*/

float[][] hmPoints = {
  {0.70, 0.28},
  {0.32, 0.41},
  {0.67, 0.50},
  {0.50, 0.86},
};

void drawFootAt(float x, float y, float w) {
  if (rightFootImg == null) {
    leftFootImg  = loadImage("Left_foot.png");
    rightFootImg = loadImage("Right_foot.png");
  }
  image = rightFootImg; //change this to change which diagram to use

  float h = w * image.height / image.width;
  image(image, x, y, w, h);

  float[] vals = {mfBuf[BUF-1], lfBuf[BUF-1], mmBuf[BUF-1], heelBuf[BUF-1]};
  for (int i = 0; i < vals.length; i++) {
    drawPressureRings(x + (1 - hmPoints[i][0]) * w, y + hmPoints[i][1] * h, vals[i], w * 0.035);
  }
}

void drawPressureRings(float cx, float cy, float value, float ringStep) {
  if (value < HM_MIN) return;
  int levels = min(int((value - HM_MIN) / HM_STEP) + 1, HM_MAX_LEVELS);

  noStroke();
  for (int i = levels - 1; i >= 0; i--) {
    fill(hmColors[i]);
    float r = ringStep * (i + 1);
    ellipse(cx, cy, r * 2, r * 2);
  }
}
