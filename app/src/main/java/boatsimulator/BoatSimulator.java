package boatsimulator;

public class BoatSimulator {

    public static void main(String[] args){
        new BoatSimulator(); // future: add options before loading game up, ideas in notes but also include resolution settings and hourglass mode (enemy always spawns in front of player, not randomly)
    }

    public BoatSimulator() {
        new RunGame();
    }
}
