import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

import processing.event.*;

class SubwaySurfersTest {
	
	// TrackBoards Tests
	
	TrackBoards tb1 = new TrackBoards(SSConstants.BOARD_INITIAL_Z);
	TrackBoards tb2 = new TrackBoards(SSConstants.DELETE_POINT-SSConstants.gameSpd);
	
	@Test // tests every testable method
	void testTrackBoards() {
		tb1.update();
		assertEquals(SSConstants.BOARD_INITIAL_Z+SSConstants.gameSpd, tb1.getPos().getZ());
		assertFalse(tb1.isOffScreen());

		assertFalse(tb2.isOffScreen());
		assertEquals(SSConstants.DELETE_POINT-SSConstants.gameSpd, tb2.getPos().getZ());
		tb2.update(); // pushes the board past the delete point
		assertTrue(tb2.isOffScreen());
		tb2.reset();
		assertEquals(SSConstants.BOARD_INITIAL_Z, tb2.getPos().getZ());
		
	}
	
	// Train Tests
	
	Train t = new Train(100, 2, 10, false);
	
	@Test
	void testTrainUpdate() {
		assertEquals(SSConstants.TRAIN_INITIAL_Z-t.getLength()/2 ,t.getPos().getZ());
		t.update();
		assertEquals(SSConstants.TRAIN_INITIAL_Z-t.getLength()/2+t.getVel().getZ(), t.getPos().getZ());
	}
	
	// Player Tests
	
	Player p = new Player();
	
	KeyEvent a = new KeyEvent(null, 0, 0, 0, 'a', java.awt.event.KeyEvent.VK_A);
	KeyEvent d = new KeyEvent(null, 0, 0, 0, 'd', java.awt.event.KeyEvent.VK_D);
	KeyEvent w = new KeyEvent(null, 0, 0, 0, 'w', java.awt.event.KeyEvent.VK_W);
	
	@Test
	void testMove() {
		assertEquals(SSConstants.tracks[1], SSConstants.tracks[p.getCurrentTrack()-1]);
		p.move(a);
		p.update();
		assertEquals(SSConstants.tracks[0], SSConstants.tracks[p.getCurrentTrack()-1]);
		p.move(d);
		p.update();
		assertEquals(SSConstants.tracks[1], SSConstants.tracks[p.getCurrentTrack()-1]);
		p.move(d);
		p.update();
		assertEquals(SSConstants.tracks[2], SSConstants.tracks[p.getCurrentTrack()-1]);
		p.move(a);
		p.update();
		assertEquals(SSConstants.tracks[1], SSConstants.tracks[p.getCurrentTrack()-1]);

	}
	
	@Test
	void testGravity() {
		assertEquals(new Player().getVel(), p.getVel());
		p.jump();
		assertEquals(new Vector(0, -16, 0), p.getVel());
		p.update(); // updates twice to make sure player is "in the air"
		p.update();
		assertEquals(new Vector(0, -16, 0).translate(p.getGravity()), p.getVel());
	}
	
	@Test 
	void testJump() {
		assertEquals(new Player().getVel(), p.getVel());
		p.jump();
		assertEquals(new Vector(0, -16, 0), p.getVel());
	}
	
	@Test // since the player has not been moved updating it should be the same as doing nothing to it
	void testPlayerUpdate() {
		p.update();
		assertEquals(new Player(), p);
	}

	
	// Obstacle Tests
	
	Barrier o1 = new Barrier(1);
	Barrier o2 = new Barrier(2);
	Barrier o3 = new Barrier(3);
	
	@Test
	void testObstacleUpdate() {
		assertEquals(new Vector(SSConstants.tracks[0], SSConstants.ENVIRONMENT_Y-30, SSConstants.TRAIN_INITIAL_Z), 
				o1.getPos());
		o1.update();
		assertEquals(new Vector(SSConstants.tracks[0], SSConstants.ENVIRONMENT_Y-30, SSConstants.TRAIN_INITIAL_Z+SSConstants.gameSpd), 
				o1.getPos());
		
		assertEquals(new Vector(SSConstants.tracks[1], SSConstants.ENVIRONMENT_Y-30, SSConstants.TRAIN_INITIAL_Z), 
				o2.getPos());
		o2.update();
		assertEquals(new Vector(SSConstants.tracks[1], SSConstants.ENVIRONMENT_Y-30, SSConstants.TRAIN_INITIAL_Z+SSConstants.gameSpd), 
				o2.getPos());
		
		assertEquals(new Vector(SSConstants.tracks[2], SSConstants.ENVIRONMENT_Y-30, SSConstants.TRAIN_INITIAL_Z), 
				o3.getPos());
		o3.update();
		assertEquals(new Vector(SSConstants.tracks[2], SSConstants.ENVIRONMENT_Y-30, SSConstants.TRAIN_INITIAL_Z+SSConstants.gameSpd), 
				o3.getPos());
	}
	

	// Bounds3D Tests
	
	Bounds3D b3d1 = new Bounds3D(new Vector(0, 0, 0), 100, 200, 400);
	Bounds3D b3d2 = new Bounds3D(new Vector(-40, 60, 100), 400, 500, 20);
	
	@Test
	void testBounds3DUpdate() {
		b3d1.update(new Vector(100, 200, 300));
		assertEquals(new Bounds3D(new Vector(100, 200, 300), 100, 200, 400), b3d1);
		b3d2.update(new Vector(10, 300, 0));
		assertEquals(new Bounds3D(new Vector(10, 300, 0), 400, 500, 20), b3d2);
		
		b3d1.update(new Vector(100, 200, 300), 10, 20, 30);
		assertEquals(new Bounds3D(new Vector(100, 200, 300), 10, 20, 30), b3d1);
		b3d2.update(new Vector(10, 300, 0), 20, 200, 4000);
		assertEquals(new Bounds3D(new Vector(10, 300, 0), 20, 200, 4000), b3d2);
	}
	
	// Bounds Tests
	
	Bounds b1 = new Bounds(new Vector(0, 0, 0), 100, 200);
	Bounds b2 = new Bounds(new Vector(-40, 60, 100), 400, 500);
	
	@Test
	void testBoundsUpdate() {
		b1.update(new Vector(100, 200, 300));
		assertEquals(new Bounds(new Vector(100, 200, 300), 100, 200), b1);
		b2.update(new Vector(10, 300, 0));
		assertEquals(new Bounds(new Vector(10, 300, 0), 400, 500), b2);
		
		b1.update(new Vector(100, 200, 300), 150, 400);
		assertEquals(new Bounds(new Vector(100, 200, 300), 150, 400), b1);
		b2.update(new Vector(100, 200, 300), 10, 20);
		assertEquals(new Bounds(new Vector(100, 200, 300), 10, 20), b2);
	}
	
	// Vector Tests

	Vector v1 = new Vector(10, 20 ,40);
	Vector v2 = new Vector(-30, 40 ,1000);
	Vector v3 = new Vector(100, -20 ,-400);
	Vector v4 = new Vector(10, 20 ,40);
	

	@Test
	void testTranslate() {
		v1.translate(v2);
		assertEquals(new Vector(-20, 60, 1040), v1);
		v2.translate(v3);
		assertEquals(new Vector(70, 20, 600), v2);
	}
	
	@Test
	void testEqualTo() {
		assertTrue(v1.equalTo(v4));
		assertFalse(v1.equalTo(v2));
	}
	
	@Test
	void testNewX() {
		v1.newX(100);
		assertEquals(new Vector(100, 20, 40), v1);
		v2.newX(0);
		assertEquals(new Vector(0, 40, 1000), v2);
		v3.newX(-40);
		assertEquals(new Vector(-40, -20, -400), v3);
	}
	
	@Test
	void testNewY() {
		v1.newY(10);
		assertEquals(new Vector(10, 10, 40), v1);
		v2.newY(0);
		assertEquals(new Vector(-30, 0, 1000), v2);
		v3.newY(-40);
		assertEquals(new Vector(100, -40, -400), v3);
	}
	
	@Test
	void testNewZ() {
		v1.newZ(10);
		assertEquals(new Vector(10, 20, 10), v1);
		v2.newZ(0);
		assertEquals(new Vector(-30, 40, 00), v2);
		v3.newZ(-40);
		assertEquals(new Vector(100, -20, -40), v3);
	}
	
	@Test
	void testHighscore() {
		Highscore.setHighScore(100);
		assertEquals(100, Highscore.getHighscore());
		
		Highscore.setHighScore(0);
		assertEquals(0, Highscore.getHighscore());
		
		
	}
}
