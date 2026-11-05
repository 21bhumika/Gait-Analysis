import java.io.*;
import java.util.*;

public class Highscore {

	public static String path = "Highscore.txt";
	private static int highscore;

	public static void scanFile() {
		try {
			Scanner sc = new Scanner(new File(path));
			if (sc.hasNextInt()) highscore = sc.nextInt();
			sc.close();
		} catch (FileNotFoundException e) {
			highscore = 0;
		}
	}

	public static int getHighscore() {
		return highscore;
	}

	public static void setHighScore(int score) {
		highscore = score;
		try {
			PrintWriter pw = new PrintWriter(new File(path));
			pw.println(score);
			pw.close();
		} catch (FileNotFoundException e) {
			System.out.println("Could not save the high score: " + e.getMessage());
		}
	}

}
