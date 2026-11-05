/* represents the bounds of an entity that is represented as a square drawn from its center point */

import java.util.Objects;

class Bounds {
	
	private float tBound;
	private float bBound;
	private float rBound;
	private float lBound;
	
	private Vector pos;
	
	private int width;
	private int height;
	
	
	Bounds(Vector pos, int width, int height) {
		this.pos = pos;
		this.width = width;
		this.height = height;
		
		this.tBound = pos.getY() - height/2;
		this.bBound = pos.getY() + height/2;
		this.rBound = pos.getX() + width/2;
		this.lBound = pos.getX() - width/2;
	}
	
	/* produces an updated version of this Bounds */
	Bounds update(Vector p) {
		//return new Bounds(p, width, height);
		return this.update(p, width, height);
	}
	
	Bounds update(Vector p, int width, int height) {
		//return new Bounds(p, width, height);
		this.pos = p;
		this.width = width;
		this.height = height;
		this.tBound = pos.getY() - height/2;
		this.bBound = pos.getY() + height/2;
		this.rBound = pos.getX() + width/2;
		this.lBound = pos.getX() - width/2;
		
		return this;
	}

	public float gettBound() {
		return tBound;
	}

	public float getbBound() {
		return bBound;
	}

	public float getrBound() {
		return rBound;
	}

	public float getlBound() {
		return lBound;
	}

	public int hashCode() {
		return Objects.hash(bBound, height, lBound, pos, rBound, tBound, width);
	}

	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Bounds other = (Bounds) obj;
		return Float.floatToIntBits(bBound) == Float.floatToIntBits(other.bBound) && height == other.height
				&& Float.floatToIntBits(lBound) == Float.floatToIntBits(other.lBound) && Objects.equals(pos, other.pos)
				&& Float.floatToIntBits(rBound) == Float.floatToIntBits(other.rBound)
				&& Float.floatToIntBits(tBound) == Float.floatToIntBits(other.tBound) && width == other.width;
	}
	
	
}
