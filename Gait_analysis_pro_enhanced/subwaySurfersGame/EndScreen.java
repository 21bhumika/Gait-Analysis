import processing.core.PApplet;
import processing.event.KeyEvent;

public class EndScreen implements IWorld {
	private int score;
	
	private Environment e;
	
	private float camX;

	public EndScreen(int score, float x) {
		this.score = score;
		
		this.e = new Environment();
		
		this.camX = x;
	}
	
	//SSConstants.WIDTH/2f
	@Override
	public PApplet draw(PApplet c) {
		c.camera(camX, SSConstants.HEIGHT/2f, (SSConstants.HEIGHT/2f) / c.tan(c.PI*30.0f / 180.0f), camX, SSConstants.HEIGHT/2f, 0f, 0f, 1f, 0f);
		c.background(25, 30, 35);
		
		e.draw(c);
		
		c.pushMatrix();
		
		c.translate(camX - SSConstants.WIDTH/2f, 0);
		
		c.textFont(SSConstants.font);
		c.textAlign(3);
		
		c.pushMatrix();
		c.translate(0, 0, -10);
		c.fill(220, 220, 25);
		c.textSize(180);
		c.text("GamE", SSConstants.WIDTH/2, 160);
		c.textSize(230);
		c.text("Over!", SSConstants.WIDTH/2, 340);
		
		c.noStroke();
		c.fill(240);
		c.rect(SSConstants.WIDTH/2, 453, 540, 160, 10);
		
		c.fill(255, 255, 100);
		c.rect(SSConstants.WIDTH/2, 362, 560, 5, 18);
		c.rect(SSConstants.WIDTH/2, 542, 560, 5, 18);
		c.stroke(0);
		
		c.textSize(52);
		c.text("Your Score: " + score, SSConstants.WIDTH / 2, 435);
		c.text("HighScore: " + Highscore.getHighscore(), SSConstants.WIDTH / 2, 510);
		
		c.textSize(82);
		c.text("Press Any Key To Play Again!", SSConstants.WIDTH/2 + 2, 700);
		
		c.popMatrix();
		
		c.fill(190, 90, 0);
		
		c.textSize(170);
		c.text("GamE", SSConstants.WIDTH/2, 160);
		c.textSize(220);
		c.text("Over!", SSConstants.WIDTH/2, 340);
		
		c.noStroke();
		c.rect(SSConstants.WIDTH/2, 365, 545, 5, 18);
		c.rect(SSConstants.WIDTH/2, 543, 545, 5, 18);
		c.stroke(0);
		
		c.textSize(50);
		c.text("Your Score: " + score, SSConstants.WIDTH / 2, 435);
		c.text("HighScore: " + Highscore.getHighscore(), SSConstants.WIDTH / 2, 510);
		
		c.textSize(80);
		c.text("Press Any Key To Play Again!", SSConstants.WIDTH/2, 695);
		
		c.popMatrix();
		return c;
	}

	@Override
	public IWorld update() {
		return this;
	}

	@Override
	public IWorld keyPressed(KeyEvent kev) {
		// TODO Auto-generated method stub
		return new SubwaySurfers();
	}

}
