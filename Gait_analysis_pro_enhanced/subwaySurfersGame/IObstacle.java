import processing.core.PApplet;

/**
 * Represents something that the player will interact with that affects the game
 */
public interface IObstacle {
	
	/**
	 * updates the obstacles position and bounds
	 */
	void update();
	
	/**
	 * renders the obstacle
	 */
	void draw(PApplet c);
	
	/**
	 * returns the frontZ of the IObstacle
	 */
	float getFrontZ();
	
	/**
	 * returns the rearZ of the IObstacle
	 */
	float getRearZ();
	
	/**
	 * returns the topY of the IObstacle
	 */
	float getTop();
	
	/**
	 * returns the rightBound of the IObstacle
	 */
	float getRight();
	
	/**
	 * returns the leftBound of the IObstacle
	 */
	float getLeft();
	
	/**
	 * Returns a string representing the type of obstacle this obstacle is
	 */
	String getType();

}
