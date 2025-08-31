package boatsimulator;

import edu.macalester.graphics.Image;

public class PlayerBoat extends Boat {
    public PlayerBoat() {
        super.shipShape = new Image("SloopScaled.png");
        super.scaleShipShape(1);
        super.name = "Player";
        super.shipHeading = 270; // initial is facing upwards
    }
}
