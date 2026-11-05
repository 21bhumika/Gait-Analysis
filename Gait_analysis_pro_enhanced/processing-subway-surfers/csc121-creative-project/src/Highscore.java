import java.io.*;
import java.util.*;

public class Highscore {

	private static int highscore;

	public static void scanFile() {
		Scanner sc;
		try {
			
			sc = new Scanner(new File("Highscore.txt"));
			highscore = sc.nextInt();
	
			sc.close();
		} catch (FileNotFoundException e) {
			
			e.printStackTrace();
		}

	}
	
	public static int getHighscore() {
		return highscore;
	}
	
	public static void setHighScore(int score) {
		PrintWriter pw;
		try {
			pw = new PrintWriter(new File("Highscore.txt"));
			
			highscore = score;
			
			pw.println(score);
			
			pw.close();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
	}

}
