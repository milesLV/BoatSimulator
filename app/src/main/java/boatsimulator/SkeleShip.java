package boatsimulator;

import edu.macalester.graphics.Image;

public class SkeleShip extends Boat {
    
    public SkeleShip() {
        super.shipShape = new Image("SkeleSloopScaled.png");
        super.name = "Skele";
        super.scaleShipShape(1);
    }

    /*
     * AI Ideas:
     * Want to make the ship so always chasing down and puts up a decent fight
     * Someone suggested making different states and behaviors to match them:
     * 1. Chasing - if player is far away, go full speed towards them (aim for to the left of them so don't actually clip)
     * 2. Attacking - if in range, slow down and try to circle them while firing (if too close, back up)
     *    Goal is to keep player as much in the range as possible so slow down / turn wheel as needed
     *    (but not so much that just throws by moving slowly or getting into really dangerous positions to achieve it– will need tweaking)
     * 2.5 Circle of death - if get mast down, slow down to mid sail and circle them 
     * 3. Fleeing - if health low / calculate that water will kill in n seconds (make this a random ranger), try to get away and repair (if can't get away, fight to the death)
     *    Bucketing water till a certain degree is top priotity, then repairing a few holes if rate is above > n number (also maybe a tiny range), then repairing mast if down, then doing of repairing holes and bucketing water
     * 
     * Advanced behaviors: 
     *  Trying to cross the T on player
     *  
     */
}
