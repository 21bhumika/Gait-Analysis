import processing.core.PApplet;
import processing.event.KeyEvent;

public class StartScreen implements IWorld{
	
	Environment e;
	
	StartScreen() {
		e = new Environment();
	}

	@Override
	public PApplet draw(PApplet c) {
		c.camera(SSConstants.tracks[1], SSConstants.HEIGHT / 2,
				SSConstants.CAMERA_Z, SSConstants.tracks[1],
				SSConstants.HEIGHT, 0, 0, 1, 0);
		
		e.draw(c);
		
		c.pushMatrix();
		c.translate(0, 0, SSConstants.PLAYER_Z);
		
		c.textFont(SSConstants.font);
		c.textAlign(3);
		
		c.pushMatrix();
		c.translate(0, 0, -10);
		c.fill(220, 220, 25);
		c.textSize(110);
		c.text("SubwaY", SSConstants.WIDTH/2, 325);
		c.textSize(150);
		c.text("SurferS", SSConstants.WIDTH/2, 435);
		
		c.noStroke();
		c.fill(255, 255, 100);
		c.rect(SSConstants.WIDTH/2, 458, 560, 5, 18);
		c.stroke(0);
		
		c.textSize(42);
		c.text("HighScore: " + Highscore.getHighscore(), SSConstants.WIDTH / 2, 500);
		
		c.textSize(62);
		c.text("Press Any Key To Start!", SSConstants.WIDTH/2 + 2, 780);
		
		
		
		c.popMatrix();
		
		c.fill(190, 90, 0);
		
		c.textSize(100);
		c.text("SubwaY", SSConstants.WIDTH/2, 325);
		c.textSize(140);
		c.text("SurferS", SSConstants.WIDTH/2, 435);
		
		c.noStroke();
		c.rect(SSConstants.WIDTH/2, 458, 545, 5, 18);
		c.stroke(0);
		
		c.textSize(40);
		c.text("HighScore: " + Highscore.getHighscore(), SSConstants.WIDTH / 2, 500);
		
		c.textSize(60);
		c.text("Press Any Key To Start!", SSConstants.WIDTH/2, 775);
		c.popMatrix();
		return c;
	}

	@Override
	public IWorld update() {
		// TODO Auto-generated method stub
		return this;
	}

	@Override
	public IWorld keyPressed(KeyEvent kev) {
		// TODO Auto-generated method stub
		return new SubwaySurfers();
	}

}
