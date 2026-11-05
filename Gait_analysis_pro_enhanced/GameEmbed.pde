import com.jogamp.newt.opengl.GLWindow;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferInt;

EmbeddedGame game = null;
BufferedImage gameImage = null;
int[] gamePixels = null;
volatile int gameFrames = 0;
volatile String gameError = "";
int gamePlayTab = 0;

// OpenGL stops drawing when its window is hidden, so this one stays open but off-screen.
class EmbeddedGame extends SSApp {
  public void settings() {
    super.settings();
    pixelDensity(1);
  }

  public void setup() {
    super.setup();
    surface.setLocation(-10000, 0);
    frameRate(60);
  }

  public void draw() {
    try {
      super.draw();
      loadPixels();
      arrayCopy(pixels, gamePixels);
      if (gameFrames == 0) hideGameWindow((GLWindow) surface.getNative());
      gameFrames++;
    } catch (RuntimeException e) {
      gameError = e.toString();
      println("Game stopped: " + e);
      noLoop();
    }
  }

  public void exitActual() {
  }
}

// JOGL's shutdown hook can hang once a second sketch is open.
void exitActual() {
  Runtime.getRuntime().halt(0);
}

void startGame() {
  if (game != null) {
    game.loop();
    return;
  }
  gameImage = new BufferedImage(SSConstants.WIDTH, SSConstants.HEIGHT, BufferedImage.TYPE_INT_RGB);
  gamePixels = ((DataBufferInt) gameImage.getRaster().getDataBuffer()).getData();
  Highscore.path = sketchPath("subwaySurfersGame/Highscore.txt");
  game = new EmbeddedGame();
  final String[] args = {"--sketch-path=" + sketchPath("subwaySurfersGame"), "Subway Surfers"};
  new Thread(new Runnable() {
    public void run() {
      PApplet.runSketch(args, game);
    }
  }).start();
}

// macOS keeps titled windows partly on-screen, so the title bar has to go. This can't run
// on the game's own drawing thread or it stalls.
void hideGameWindow(final GLWindow window) {
  new Thread(new Runnable() {
    public void run() {
      window.setUndecorated(true);
      window.setPosition(-10000, 0);
      focusMainWindow();
    }
  }).start();
}

void focusMainWindow() {
  processing.awt.PSurfaceAWT.SmoothCanvas canvas = (processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative();
  canvas.getFrame().toFront();
  canvas.requestFocus();
}

void pauseGame() {
  if (game == null) return;
  game.noLoop();
  Sounds.stopMainTheme();
  Sounds.stopRunSound();
}

boolean gameRunning() {
  return game != null && gameFrames > 0 && gameError.length() == 0;
}

void sendGameKey(char c) {
  if (!gameRunning()) return;
  game.postEvent(new processing.event.KeyEvent(null, System.currentTimeMillis(),
    processing.event.KeyEvent.PRESS, 0, c, java.awt.event.KeyEvent.getExtendedKeyCodeForChar(c)));
}

void drawGameView(int x, int y, int w, int h) {
  noStroke();
  fill(#1C1C1E);
  rect(x, y, w, h, CARD_R);

  if (!gameRunning()) {
    tx(22, true, color(255), CENTER, CENTER);
    text(gameError.length() > 0 ? "The game stopped" : "Loading game...", x + w / 2, y + h / 2 - 8);
    tx(14, false, color(190), CENTER, CENTER);
    text(gameError.length() > 0 ? gameError : "This takes a few seconds the first time", x + w / 2, y + h / 2 + 20);
    return;
  }

  Graphics2D g2 = ((processing.awt.PGraphicsJava2D) g).g2;
  java.awt.Shape oldClip = g2.getClip();
  Object oldHint = g2.getRenderingHint(RenderingHints.KEY_INTERPOLATION);
  g2.clip(new RoundRectangle2D.Float(x, y, w, h, CARD_R * 2, CARD_R * 2));
  g2.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
  g2.drawImage(gameImage, x, y, w, h, null);
  if (oldHint != null) g2.setRenderingHint(RenderingHints.KEY_INTERPOLATION, oldHint);
  g2.setClip(oldClip);
}
