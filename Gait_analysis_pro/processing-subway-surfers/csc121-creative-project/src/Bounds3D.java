import java.util.Objects;

class Bounds3D {
	
	private float frontZ;
	private float backZ;
	private float rBound;
	private float lBound;
	private float top;
	
	private Vector pos;
	
	private int width;
	private int height;
	private int depth;
	
	
	Bounds3D(Vector pos, int width, int height, int depth) {
		this.pos = pos;
		this.width = width;
		this.height = height;
		this.depth = depth;
		
		this.frontZ = pos.getZ() + depth/2;
		this.backZ = pos.getZ() - depth/2;
		this.rBound = pos.getX() + width/2;
		this.lBound = pos.getX() - width/2;
		this.top = SSConstants.floorLvl - height;
	}
	
	/* produces an updated version of this Bounds */
	Bounds3D update(Vector p) {
		return this.update(p, width, height, depth);
	}
	
	Bounds3D update(Vector p, int width, int height, int depth) {
		this.pos = p;
		this.width = width;
		this.height = height;
		this.depth = depth;
		
		this.frontZ = pos.getZ() + depth/2;
		this.backZ = pos.getZ() - depth/2;
		this.rBound = pos.getX() + width/2;
		this.lBound = pos.getX() - width/2;
		this.top = SSConstants.floorLvl - height;
		
		return this;
	}

	public float getFrontZ() {
		return frontZ;
	}

	public float getRearZ() {
		return backZ;
	}
	
	public float getRBound() {
		return rBound;
	}
	
	public float getLBound() {
		return lBound;
	}

	public float getTop() {
		return top;
	}

	public int hashCode() {
		return Objects.hash(backZ, depth, frontZ, height, pos, top, width);
	}

	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Bounds3D other = (Bounds3D) obj;
		return Float.floatToIntBits(backZ) == Float.floatToIntBits(other.backZ) && depth == other.depth
				&& Float.floatToIntBits(frontZ) == Float.floatToIntBits(other.frontZ) && height == other.height
				&& Objects.equals(pos, other.pos) && Float.floatToIntBits(top) == Float.floatToIntBits(other.top)
				&& width == other.width;
	}
	
	

}
