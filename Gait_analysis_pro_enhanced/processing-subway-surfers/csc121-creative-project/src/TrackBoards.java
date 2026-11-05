import processing.core.PApplet;

class TrackBoards {
	private int width = 200;
	private int height = 15;
	private int depth = 50;
	
	private Vector pos;
	
	private boolean offScreen = false;
	
	TrackBoards(float z) {
		pos = new Vector(0, SSConstants.ENVIRONMENT_Y, z);
	}
	
	void draw(PApplet c) {
		c.fill(40, 20, 0);
		
		c.pushMatrix();
		c.translate(100, pos.getY(), pos.getZ());
		c.box(width, height, depth);
		c.popMatrix();
		
		c.pushMatrix();
		c.translate(600, pos.getY(), pos.getZ());
		c.box(width, height, depth);
		c.popMatrix();
		
		c.pushMatrix();
		c.translate(1100, pos.getY(), pos.getZ());
		c.box(width, height, depth);
		c.popMatrix();
		
		reset();
	}
	
	void update() {
		pos.newZ(pos.getZ() + SSConstants.gameSpd);
		offScreen = pos.getZ() >= SSConstants.DELETE_POINT;
	}
	
	void reset() {
		if (offScreen) {
			pos.newZ(SSConstants.BOARD_INITIAL_Z);
			offScreen = false;
		}
	}

	public Vector getPos() {
		return pos;
	}

	public boolean isOffScreen() {
		return offScreen;
	}
	
	

}
