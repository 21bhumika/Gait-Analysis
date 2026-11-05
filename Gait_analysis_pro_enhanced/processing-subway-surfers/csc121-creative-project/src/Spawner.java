import java.util.ArrayList;

public class Spawner {

	private ArrayList<Train> t1Trains;// trains on track 1
	private ArrayList<Train> t2Trains; // trains on track 2
	private ArrayList<Train> t3Trains; // trains on track 3

	private ArrayList<Barrier> t1Barriers; // trains on track 1
	private ArrayList<Barrier> t2Barriers; // trains on track 2
	private ArrayList<Barrier> t3Barriers; // trains on track 3

	private ArrayList<IObstacle> allObstacles = new ArrayList<IObstacle>(); // combined list of all trains

	public Spawner() {
		t1Trains = new ArrayList<Train>();
		t2Trains = new ArrayList<Train>();
		t3Trains = new ArrayList<Train>();
		
		t1Barriers = new ArrayList<Barrier>();
		t2Barriers = new ArrayList<Barrier>();
		t3Barriers = new ArrayList<Barrier>();
	}
	
	/**
	 * If the chance falls below the spawn threshold, attempts to spawn trains based
	 * on individual track thresholds
	 */
	public void spawn() {
		double chance = SSConstants.rgen.nextDouble();
		
		// something needs to be spawned
		if (chance <= SSConstants.OBSTACLE_SPAWN_RATE) {
			// which track to put an obstacle on
			int trackToSpawn = SSConstants.rgen.nextInt(1, 4);
			// whether or not the obstacle is a barrier
			boolean isBarrier = SSConstants.rgen.nextDouble() < SSConstants.BARRIER_SPAWN_RATE;
			
			if (isBarrier) addBarrier(trackToSpawn);
			else {
				// 1 in 2 chance a train has a barrier
				boolean hasRamp = SSConstants.rgen.nextInt(2) == 1;
				addTrain(trackToSpawn, hasRamp);
			}
		}
	}

	/**
	 * Adds a barrier to the given track
	 */
	 public void addBarrier(int track) {
		Barrier b = new Barrier(track);
		switch (track) {
		case 1:
			t1Barriers.add(b);
			break;
		case 2:
			t2Barriers.add(b);
			break;
		case 3:
			t3Barriers.add(b);
			break;
		}
	}

	/**
	 * Adds a train with a random length and speed to the given track
	 */
	public void addTrain(int track, boolean hasRamp) {
		switch (track) {
		case 1:
			t1Trains.add(new Train(SSConstants.rgen.nextInt(3001 - 600) + 600, track,
					SSConstants.rgen.nextInt(20 - 5) + 5, hasRamp));
			break;
		case 2:
			t2Trains.add(new Train(SSConstants.rgen.nextInt(3001 - 600) + 600, track,
					SSConstants.rgen.nextInt(20 - 5) + 5, hasRamp));
			break;
		case 3:
			t3Trains.add(new Train(SSConstants.rgen.nextInt(3001 - 600) + 600, track,
					SSConstants.rgen.nextInt(20 - 5) + 5, hasRamp));
			break;
		}
	}

	/**
	 * Returns a combined list of all the obstacles in the three track arrays
	 */
	public ArrayList<IObstacle> getAllObstacles() {
		if (allObstacles.size() > 0) {
			allObstacles.clear();
		}
		
		allObstacles.addAll(t1Trains);
		allObstacles.addAll(t2Trains);
		allObstacles.addAll(t3Trains);
		allObstacles.addAll(t1Barriers);
		allObstacles.addAll(t2Barriers);
		allObstacles.addAll(t3Barriers);
		return allObstacles;
	}
	
	/**
	 * Returns a combined list of all the Trains on the requested track
	 */
	public ArrayList<Train> getTrainsOn(int track) {
		ArrayList<Train> out = new ArrayList<Train>();
		switch (track) {
		case 1:
			out.addAll(t1Trains);
			break;
		case 2:
			out.addAll(t2Trains);
			break;
		case 3:
			out.addAll(t3Trains);
			break;
		}
		return out;
	}
	
	/**
	 * Returns a combined list of all the Barriers on the requested track
	 */
	public ArrayList<Barrier> getBarriersOn(int track) {
		ArrayList<Barrier> out = new ArrayList<Barrier>();
		switch (track) {
		case 1:
			out.addAll(t1Barriers);
			break;
		case 2:
			out.addAll(t2Barriers);
			break;
		case 3:
			out.addAll(t3Barriers);
			break;
		}
		return out;
	}

	/**
	 * Updates all the obstacles on each track
	 */
	public void updateObstacles() {
		t1Trains.removeIf(ob -> ob.isOffScreen()); // off the screen
		t1Trains.forEach(ob -> ob.update());

		t2Trains.removeIf(ob -> ob.isOffScreen()); // off the screen
		t2Trains.forEach(ob -> ob.update());

		t3Trains.removeIf(ob -> ob.isOffScreen()); // off the screen
		t3Trains.forEach(ob -> ob.update());
		
		t1Barriers.removeIf(ob -> ob.isOffScreen()); // off the screen
		t1Barriers.forEach(ob -> ob.update());

		t2Barriers.removeIf(ob -> ob.isOffScreen()); // off the screen
		t2Barriers.forEach(ob -> ob.update());

		t3Barriers.removeIf(ob -> ob.isOffScreen()); // off the screen
		t3Barriers.forEach(ob -> ob.update());
	}
	
	public void removeAllObstacles() {
		allObstacles.removeAll(allObstacles);
	}

}
