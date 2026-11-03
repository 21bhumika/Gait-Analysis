import processing.core.*;

class Building {

	private int size;

	private int width = 600;
	private int height;
	private int depth = 600;

	private boolean onRight;
	private boolean offScreen;
	
	private static int spawnPoint = SSConstants.TRAIN_INITIAL_Z - 1000;

	private Vector pos;
	
	private PShape box2; // creates a texturable box shape

	Building(float z, int size, boolean onRight) {
		this.size = size;
		this.onRight = onRight;
		choosePos();
		pos.newZ(z);
	}

	// commented out code lets the building have texture but causes lag
	void draw(PApplet c) {
		c.fill(60);
		c.pushMatrix();
		c.translate(pos.getX(), pos.getY(), pos.getZ());
		//box2 = c.createShape(c.BOX, width, height, depth); 
		//box2.setTexture(SSConstants.buildingTexture);
		//c.shape(box2);
		c.box(width, height, depth);
		c.popMatrix();
	}
	
	/** updates the building position and offScreen boolean, 
	 * if it is offscreen then sets the building back at the beginning with a random height */
	void update() {
		pos.newZ(pos.getZ() + SSConstants.gameSpd);
		
		offScreen = pos.getZ() >= SSConstants.DELETE_POINT;
		
		if (offScreen) {
			size = SSConstants.rgen.nextInt(3);
			choosePos();
			pos.newZ(spawnPoint);
		}
	}

	void choosePos() {
		pos = new Vector(0, 0, 0);

		switch(size) {
		case 0:
			height = 850;
			pos.newY(425);
			break;
		case 1:
			height = 1050;
			pos.newY(325);
			break;
		case 2:
			height = 1200;
			pos.newY(250);
			break;
		}
		
		if (onRight) {
			pos = pos.newX(2000);
		} else {
			pos = pos.newX(-800);
		}
	}

	public Vector getPos() {
		return pos;
	}
}
