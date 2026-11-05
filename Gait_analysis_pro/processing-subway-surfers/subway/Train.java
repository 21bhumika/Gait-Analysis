import java.util.Objects;

import processing.core.PApplet;

/**
 * Represents a train obstacle that moves toward the player
 */
public class Train implements IObstacle {
	private int track; // the track that the train will be on

	private int length; // length of the train
	private int width = SSConstants.TRAIN_WIDTH;
	private int height = SSConstants.TRAIN_HEIGHT;

	private boolean hasRamp; // whether or not the train has a ramp on the front the player can run up

	private Vector vel;

	private Vector pos;

	private Bounds3D bounds;

	private float rearZ; // z for the rear of the train
	private float frontZ; // z for the front of the train
	private float top; // top bound of the train

	private boolean offScreen = false; // boolean for when the obstacle has moved off the screen

	public Train(int length, int track, float speed, boolean hasRamp) {
		this.track = track;
		this.length = length;
		this.pos = new Vector(SSConstants.tracks[track - 1], SSConstants.TRAIN_Y,
				SSConstants.TRAIN_INITIAL_Z - length / 2);

		this.hasRamp = hasRamp;
		this.vel = hasRamp ? new Vector(0, 0, SSConstants.gameSpd) : new Vector(0, 0, (SSConstants.gameSpd + speed));

		this.bounds = new Bounds3D(pos, width, height, length);
	}

	/**
	 * Renders the train on the given scene by drawing each of its frames
	 */
	public void draw(PApplet c) {
		c.fill(100, 0, 0);
		c.pushMatrix();

		c.translate(pos.getX(), pos.getY(), pos.getZ()); // draws train body
		c.box(width, height, length);

		c.pushMatrix(); // draws front bumper
		c.fill(60);
		c.translate(0, height - 185, length / 2);
		c.box(width + 10, 60, 50);
		c.popMatrix();

		c.pushMatrix(); // draws right headlight
		c.fill(255, 255, 100);
		c.translate(width / 2 - 40, height - 250, length / 2 + 1);
		c.circle(0, 0, 50);
		c.popMatrix();

		c.pushMatrix(); // draws left headlight
		c.fill(255, 255, 100);
		c.translate(-width / 2 + 40, height - 250, length / 2 + 1);
		c.circle(0, 0, 50);
		c.popMatrix();

		c.pushMatrix(); // draws bottom middle headlight
		c.fill(255, 255, 100);
		c.translate(0, height - 260, length / 2 + 1);
		c.circle(0, 0, 35);
		c.popMatrix();

		c.pushMatrix(); // draws top middle headlight
		c.fill(255, 255, 100);
		c.translate(0, 0, length / 2 + 1);
		c.circle(0, 0, 35);
		c.popMatrix();

		c.pushMatrix(); // draws left window pane
		c.fill(0, 60, 100);
		c.translate(-width / 2 + 64, -75, length / 2 + 1);
		c.rect(0, 0, (width - 10) / 2, 75);
		c.popMatrix();

		c.pushMatrix(); // draws right window pane
		c.fill(0, 60, 100);
		c.translate(width / 2 - 64, -75, length / 2 + 1);
		c.rect(0, 0, (width - 10) / 2, 75);
		c.popMatrix();

		if (hasRamp) {
			c.pushMatrix(); // draws the ramp
			c.fill(50, 30, 10);
			c.translate(0, 0, length / 2 + 125);
			c.rotateX(10.1f);
			c.rect(0, 0, width, height + 70);
			c.popMatrix();

			c.pushMatrix(); // draws right rail
			c.fill(40);
			c.translate(width / 2 - 20, 0, length / 2 + 125);
			c.rotateX(10.1f);
			c.box(40, height + 70, 35);
			c.popMatrix();

			c.pushMatrix(); // draws left rail
			c.fill(40);
			c.translate(-width / 2 + 20, 0, length / 2 + 125);
			c.rotateX(10.1f);
			c.box(40, height + 70, 35);
			c.popMatrix();
		}

		c.popMatrix();

	}

	/**
	 * Updates the position of the train by adding the velocity, also updates the
	 * bounds
	 */
	public void update() {
		pos.newZ(pos.getZ() + vel.getZ());
		bounds.update(pos);
		frontZ = bounds.getFrontZ();
		rearZ = bounds.getRearZ();
		top = bounds.getTop();
		
		if (hasRamp) { // changes the front z for ramp trains to account for the length of the ramp
			frontZ += SSConstants.RAMP_LENGTH;
		}

		offScreen = rearZ >= SSConstants.DELETE_POINT;
	}

	public int getLength() {
		return length;
	}

	public Vector getPos() {
		return pos;
	}
	
	public Vector getVel() {
		return vel;
	}
	
	public int getTrack() {
		return track;
	}
	
	public boolean hasRamp() {
		return hasRamp;
	}

	public float getRearZ() {
		return rearZ;
	}

	public float getFrontZ() {
		return frontZ;
	}
	
	public float getTop() {
		return top;
	}
	
	public float getRight() {
		return bounds.getRBound();
	}
	
	public float getLeft() {
		return bounds.getLBound();
	}
	
	public void setVel(Vector newVel) {
		vel = newVel;
	}

	public boolean isOffScreen() {
		return offScreen;
	}
	
	public String getType() {
		return "train";
	}

	@Override
	public int hashCode() {
		return Objects.hash(bounds, frontZ, hasRamp, height, length, pos, rearZ, track, vel, width);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Train other = (Train) obj;
		return Objects.equals(bounds, other.bounds)
				&& Float.floatToIntBits(frontZ) == Float.floatToIntBits(other.frontZ) && hasRamp == other.hasRamp
				&& height == other.height && length == other.length && Objects.equals(pos, other.pos)
				&& Float.floatToIntBits(rearZ) == Float.floatToIntBits(other.rearZ) && track == other.track
				&& Objects.equals(vel, other.vel) && width == other.width;
	}

}
