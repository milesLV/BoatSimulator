package boatsimulator;

import edu.macalester.graphics.Image;

public class PlayerBoat extends Boat {
    public final static short INITIAL_HEADING = 270; // facing upwards
    public PlayerBoat() {
        super.shipShape = new Image("SloopScaled.png");
        super.scaleShipShape(1);
        super.name = "Player";
        super.shipHeading = INITIAL_HEADING;
    }
}
