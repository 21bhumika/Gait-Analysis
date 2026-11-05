import processing.core.*;

class Animation {
	// creates an image array and variable
	private PImage[] imgs;
	private PImage displayImg;

	// variables for controlling animation
	private int imgNum;
	private int index;

	// variables for the timer
	private float startTime;
	private float endTime;
	private float interval;

	// controls when the animation is running
	boolean isAnimating = true;

	PApplet c;

	// takes in an array of images and a speed
	Animation(PImage[] other, float speed, PApplet c) {
		this.imgs = other;
		this.imgNum = 0;
		this.interval = speed;
		this.c = c;

		index = other.length;
		startTime = c.millis();
	}

// takes in x and y positions and a dimensions
	void display(float x, float y, int width, int height) {
		index = imgs.length;
		displayImg = imgs[imgNum];
		displayImg.resize(width, height);
		endTime = c.millis();

// when the boolean is true the animation is updated every time the timer goes off, when it is not the image is set to the first in the array
		if (isAnimating) {
			c.image(displayImg, x, y);
			if (endTime - startTime >= interval) {
				update();
				startTime = endTime;
			}
		} else {
			imgNum = 0;
			c.image(imgs[0], x, y);
			if (endTime - startTime >= interval) {
				startTime = endTime;
			}
		}
	}

// switches to the next image until the end of the array is reached, when that happens the variable is set back to 0
	void update() {
		if (imgNum < index - 1) {
			imgNum++;
		} else {
			imgNum = 0;
		}
	}
}