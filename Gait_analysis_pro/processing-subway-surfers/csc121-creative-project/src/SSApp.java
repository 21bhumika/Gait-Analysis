import processing.core.*;
import processing.event.*;
import processing.sound.SoundFile;

/**
 * Provides the scaffolding to launch a Processing application
 */
public class SSApp extends PApplet {
	private IWorld w;

	public void settings() {
		this.size(SSConstants.WIDTH, SSConstants.HEIGHT, P3D);
		loadImages();
		loadSounds();
		
		Highscore.scanFile();
	}

	public void setup() {
		w = new StartScreen();
		SSConstants.font = createFont("Gemstone.ttf", 100);
	}

	public void draw() {
		Sounds.playMainTheme();
		
		w = w.update();
		
		w.draw(this);
		
	}

	public void keyPressed(KeyEvent kev) {
		w = w.keyPressed(kev);
	}

	public static void main(String[] args) {
		PApplet.runSketch(new String[] { "Subway Surfers" }, new SSApp());
	}

	void loadImages() {
		PImage[] playerImgs = new PImage[9];

		for (int i = 0; i < playerImgs.length; i++) {
			playerImgs[i] = loadImage("subwaysurfer" + i + ".png");
		}

		SSConstants.playerSprite = new Animation(playerImgs, 75, this);
		SSConstants.buildingTexture = loadImage("buildingTexture.png");
	}
	
	void loadSounds() {
		Sounds.jumpSound = new SoundFile(this, "jumpSound.mp3");
		//Sounds.jumpSound.amp(2.0f);
		Sounds.runSound = new SoundFile(this, "runSound.wav");
		//Sounds.runSound.amp(0.5f);
		Sounds.mainTheme = new SoundFile(this, "mainTheme.wav");
		Sounds.mainTheme.amp(0.15f);
		
		Sounds.guardSound = new SoundFile(this, "guardHey.wav");
		Sounds.guardSound.amp(0.65f);
		
		Sounds.deathSound = new SoundFile(this, "deathSound.wav");
	}

}
