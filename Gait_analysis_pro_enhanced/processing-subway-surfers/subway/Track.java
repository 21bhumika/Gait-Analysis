import java.util.Objects;

public class Track {
	private int xPos;

	Track(int xPos) {
		this.xPos = xPos;
	}

	/**
	 * @return the xPos
	 */
	public int getX() {
		return xPos;
	}

	@Override
	public int hashCode() {
		return Objects.hash(xPos);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Track other = (Track) obj;
		return xPos == other.xPos;
	}
}
