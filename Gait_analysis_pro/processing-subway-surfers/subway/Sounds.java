import processing.sound.*;

public class Sounds {

	public static SoundFile jumpSound;
	public static SoundFile runSound;
	public static SoundFile mainTheme;
	public static SoundFile guardSound;
	public static SoundFile deathSound;
	
	public static void playJumpSound() {
		if (jumpSound != null) 
			jumpSound.play();
	}
	
	public static void playRunSound() {
		if (runSound != null) {
			if (!runSound.isPlaying()) {
				runSound.play();
			}
		}
	}
	
	public static void stopRunSound() {
		if (runSound != null) {
			runSound.stop();
		}
	}
	
	public static void playMainTheme() {
		if (mainTheme != null) {
			if (!mainTheme.isPlaying()) {
				mainTheme.play();
			}
		}
	}
	
	public static void stopMainTheme() {
		if (mainTheme != null) {
			mainTheme.stop();
		}
	}
	
	public static void playGuardSound() {
		if (guardSound != null) 
			guardSound.play();
	}
	
	public static void playDeathSound() {
		if (deathSound != null) 
			deathSound.play();
	}
}
