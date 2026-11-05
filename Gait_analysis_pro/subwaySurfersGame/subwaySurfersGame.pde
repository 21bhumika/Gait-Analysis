import processing.sound.*;


void setup() {
  PApplet.runSketch(new String[] {
    "--sketch-path=" + sketchPath(),
    "Subway Surfers"
  }, new SSApp());
}
