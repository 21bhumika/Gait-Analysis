final float GRAVITY = 9.81;
final float STILL_GYRO   = 0.6;
final float STILL_ACCEL  = 1.2;
final int   STILL_SAMPLES = 3;

final float MIN_SWING_S = 0.25, MAX_SWING_S = 2.5;
final float MIN_STRIDE_M = 0.2, MAX_STRIDE_M = 3.0;

float[] footQ = null;
float[] footVel = new float[3];
float[] footPos = new float[3];
float[] stillAccel = new float[3];
float[] lastGyro = new float[3];
int stillCount = 0;
int lastBoardMs = -1;
float swingS = 0;
float gyroStrideM = 0;

synchronized void resetStride() {
  footQ = null;
  stillCount = 0;
  lastBoardMs = -1;
  swingS = 0;
  gyroStrideM = 0;
}

synchronized void updateStride(float wx, float wy, float wz, float fx, float fy, float fz, int boardMs) {
  float dt = (boardMs - lastBoardMs) / 1000.0;
  boolean firstOrGap = lastBoardMs < 0 || dt <= 0 || dt > 0.2;
  lastBoardMs = boardMs;
  if (firstOrGap) {
    footQ = null;
    stillCount = 0;
    swingS = 0;
    lastGyro = new float[] {wx, wy, wz};
    return;
  }

  float rate = sqrt(wx * wx + wy * wy + wz * wz);
  float accel = sqrt(fx * fx + fy * fy + fz * fz);
  stillCount = rate < STILL_GYRO && abs(accel - GRAVITY) < STILL_ACCEL ? stillCount + 1 : 0;

  if (stillCount >= STILL_SAMPLES) {
    if (swingS > 0) finishSwing();
    updateRestPose(fx, fy, fz);
  } else if (footQ != null) {
    integrateSwing(wx, wy, wz, fx, fy, fz, dt);
  }
  lastGyro = new float[] {wx, wy, wz};
}

void finishSwing() {
  float T = swingS;
  swingS = 0;
  if (T < MIN_SWING_S || T > MAX_SWING_S) return;

  float x = footPos[0] - footVel[0] * T / 2;
  float y = footPos[1] - footVel[1] * T / 2;
  float stride = sqrt(x * x + y * y);
  if (stride < MIN_STRIDE_M || stride > MAX_STRIDE_M) return;

  gyroStrideM = gyroStrideM == 0 ? stride : 0.7 * gyroStrideM + 0.3 * stride;
}

void updateRestPose(float fx, float fy, float fz) {
  if (stillCount == STILL_SAMPLES) stillAccel = new float[3];
  stillAccel[0] += fx;
  stillAccel[1] += fy;
  stillAccel[2] += fz;
  footQ = levelQuaternion(stillAccel);
  footVel = new float[3];
  footPos = new float[3];
}

float[] levelQuaternion(float[] a) {
  float n = sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
  float ux = a[0] / n, uy = a[1] / n, uz = a[2] / n;
  if (uz < -0.9999) return new float[] {0, 1, 0, 0};

  return normalizedQ(new float[] {1 + uz, uy, -ux, 0});
}

void integrateSwing(float wx, float wy, float wz, float fx, float fy, float fz, float dt) {
  float mx = (wx + lastGyro[0]) / 2, my = (wy + lastGyro[1]) / 2, mz = (wz + lastGyro[2]) / 2;
  float rate = sqrt(mx * mx + my * my + mz * mz);
  if (rate > 0) {
    float half = rate * dt / 2;
    float s = sin(half) / rate;
    footQ = normalizedQ(multiplyQ(footQ, new float[] {cos(half), mx * s, my * s, mz * s}));
  }

  float[] world = rotateByQ(footQ, fx, fy, fz);
  world[2] -= GRAVITY;
  for (int i = 0; i < 3; i++) {
    footVel[i] += world[i] * dt;
    footPos[i] += footVel[i] * dt;
  }
  swingS += dt;
}

float[] multiplyQ(float[] a, float[] b) {
  return new float[] {
    a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
    a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2],
    a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
    a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0]
  };
}

float[] normalizedQ(float[] q) {
  float n = sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
  return new float[] {q[0] / n, q[1] / n, q[2] / n, q[3] / n};
}

float[] rotateByQ(float[] q, float x, float y, float z) {
  float[] r = multiplyQ(multiplyQ(q, new float[] {0, x, y, z}),
                        new float[] {q[0], -q[1], -q[2], -q[3]});
  return new float[] {r[1], r[2], r[3]};
}
