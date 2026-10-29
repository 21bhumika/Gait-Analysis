String[] labels = {"Gait Analysis", "Cool Application"};
int btnW = 260, btnH = 80, btnGap = 24, btnCols = 2;

void drawHome() {
  background(240, 240, 240);

  fill(30);
  textAlign(CENTER, CENTER);
  textSize(26);
  text("Wearables Lab 4", width / 2, 80);

  fill(110);
  textSize(13);
  text("Select a module", width / 2, 115);

  for (int i = 0; i < labels.length; i++) {
    int col = i % btnCols;
    int row = i / btnCols;
    int x = (width - (btnCols * btnW + (btnCols - 1) * btnGap)) / 2 + col * (btnW + btnGap);
    int y = 180 + row * (btnH + btnGap);
    drawHomeBtn(labels[i], x, y);
  }
}

void drawHomeBtn(String label, int x, int y) {
  boolean hover = mouseX >= x && mouseX <= x + btnW && mouseY >= y && mouseY <= y + btnH;

  if (hover) {
    fill(200, 220, 255);
    stroke(70, 120, 220);
  } else {
    fill(255);
    stroke(180);
  }

  strokeWeight(1.5);
  rect(x, y, btnW, btnH, 10);

  fill(hover ? 20 : 50);
  textAlign(CENTER, CENTER);
  textSize(15);
  text(label, x + btnW / 2, y + btnH / 2);
}

void homeClick() {
  for (int i = 0; i < labels.length; i++) {
    int col = i % btnCols;
    int row = i / btnCols;
    int x = (width - (btnCols * btnW + (btnCols - 1) * btnGap)) / 2 + col * (btnW + btnGap);
    int y = 180 + row * (btnH + btnGap);
    if (mouseX >= x && mouseX <= x + btnW && mouseY >= y && mouseY <= y + btnH) {
      screen = i + 1;
    }
  }
}
