import java.util.Objects;

import processing.core.PApplet;

/**
 * Represents a barrier obstacle that moves toward the player
 */
class Barrier implements IObstacle {

	private Vector pos;
	
	private int width = SSConstants.OBSTACLE_WIDTH;
	private int height = SSConstants.OBSTACLE_HEIGHT;
	private int depth = SSConstants.OBSTACLE_DEPTH;

	private Bounds3D bounds;

	private float rearZ;  // z value for the rear of the obstacle
	private float frontZ; // z value for the front of the obstacle

	private boolean offScreen = false;  // boolean for when the obstacle has moved off the screen

	private int track;  // the track that the obstacle will be on

	private float gameSpd; // the speed of the game (how fast the obstacle will move

	Barrier(int track) {
		this.track = track;
		pos = new Vector(SSConstants.tracks[track - 1], SSConstants.ENVIRONMENT_Y - 30,
				SSConstants.TRAIN_INITIAL_Z);
		this.bounds = new Bounds3D(pos, width, height, depth);
	}

	/**
	 * updates the obstacles position and bounds
	 */
	public void update() {
		pos.newZ(pos.getZ() + SSConstants.gameSpd);
		offScreen = rearZ >= SSConstants.DELETE_POINT;

		bounds.update(pos);
		
		rearZ = bounds.getRearZ();
		frontZ = bounds.getFrontZ();
	}

	public void draw(PApplet c) {
		c.pushMatrix();
		c.fill(70);
		c.translate(pos.getX(), pos.getY(), pos.getZ());
		c.box(width, 20, depth); // draws the base

		c.pushMatrix();
		c.fill(90, 60, 40);
		c.translate(-80, -75, 0);
		c.box(40, 130, 20); // draws the left post
		c.popMatrix();

		c.pushMatrix();
		c.fill(90, 60, 40);
		c.translate(80, -75, 0);
		c.box(40, 130, 20); // draws the right post
		c.popMatrix();

		c.pushMatrix();
		c.fill(150);
		c.translate(0, -120, 0);
		c.box(width - 20, 60, 45); // draws the white bar
		c.popMatrix();

		c.pushMatrix();
		c.fill(90);
		c.strokeWeight(0.05f);
		c.translate(-80, -115, 0);
		c.sphere(30); // draws the left sphere
		c.strokeWeight(1);
		c.popMatrix();

		c.pushMatrix();
		c.fill(90);
		c.strokeWeight(0.05f);
		c.translate(80, -115, 0);
		c.sphere(30); // draws the right sphere
		c.strokeWeight(1);
		c.popMatrix();

		c.pushMatrix(); // draws the orange bars
		c.fill(190, 100, 0);
		c.translate(-100, -120, 24);
		c.rect(0, 0, 20, 60);
		c.rect(40, 0, 20, 60);
		c.rect(80, 0, 20, 60);
		c.rect(120, 0, 20, 60);
		c.rect(160, 0, 20, 60);
		c.rect(200, 0, 20, 60);
		c.popMatrix();

		c.popMatrix();
	}

	public Vector getPos() {
		return pos;
	}
	
	public float getFrontZ() {
		return frontZ;
	}
	
	public float getRearZ() {
		return rearZ;
	}
	
	public float getTop() {
		return bounds.getTop();
	}
	
	public float getRight() {
		return bounds.getRBound();
	}
	
	public float getLeft() {
		return bounds.getLBound();
	}

	public boolean isOffScreen() {
		return offScreen;
	}
	
	public String getType() {
		return "barrier";
	}

	public int hashCode() {
		return Objects.hash(bounds, depth, frontZ, gameSpd, height, offScreen, pos, rearZ, track, width);
	}

	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Barrier other = (Barrier) obj;
		return Objects.equals(bounds, other.bounds) && depth == other.depth
				&& Float.floatToIntBits(frontZ) == Float.floatToIntBits(other.frontZ)
				&& Float.floatToIntBits(gameSpd) == Float.floatToIntBits(other.gameSpd) && height == other.height
				&& offScreen == other.offScreen && Objects.equals(pos, other.pos)
				&& Float.floatToIntBits(rearZ) == Float.floatToIntBits(other.rearZ) && track == other.track
				&& width == other.width;
	}

}
