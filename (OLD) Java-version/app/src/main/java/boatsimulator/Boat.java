package boatsimulator;

import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import edu.macalester.graphics.Image;
import edu.macalester.graphics.Point;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public abstract class Boat {
    private final short MAX_WHEEL_TURN = 360;
    private final double MAX_CANNON_RANGE = 88.235; // if a square is 340 x 340 paces in game and cannon range is 300 paces
    private final double MAX_CANNON_HORIZONTAL_ROTATION = 12.5;
    private final double WHEEL_TURN_SPEED = 3.35096418733; // sloop = 3.041 secs to turn wheel fully from center
    private final double SHIP_TURN_SPEED = 0.0002803553; // sloop = 1:04.29 mins to turn 360 degrees
    private final byte MAX_BUCKET_AMOUNT = 67; // 67 buckets of water to fill the ship
    private final byte MAX_HEALTH = 100;
    private final double SHIP_SCALE = 0.10;
    private final byte MAX_SAIL_LENGTH = 100;
    private final byte MAX_MAST_HEIGHT = 100;
    private final double SAIL_RAISE_SPEED = 1.13636363636; // 5 seconds to raise sail fully
    private final byte SAIL_LOWER_SPEED = 20; // 0.88 seconds to lower
    private final byte MAST_RAISE_SPEED = 11; // 9 seconds to raise mast fully (need to test)

    private final byte ANCHOR_RAISE_SPEED = 20; // 5 seconds to raise
    private final byte ANCHOR_LOWER_SPEED = 25; // 4 seconds to lower
    private final double ANCHOR_DECELERATION = 0.01; // deceleration when anchor is down
    private final double ACCELERATION_INCREMENT = 0.0008; // acceleration and deceleration (not sure if correct but made decision); need to do test
    private final double FRICTION_INCREMENT = 0.0002;
    private final double MAX_SHIP_VELOCITY = 0.21780408801;
    private final byte MAX_BILLOW_AMOUNT = 100;

    private double shipX;
    private double shipY;
    private short shipHealth = MAX_HEALTH;
    private boolean shipAlive = true;
    public byte[] shipHoles = new byte[15]; // maybe in the future will split this up into 2: left = 7, right = 8
    public byte[] mastHoles = new byte[3];
    private double shipVelocity = 0;
    private double maxSpeedGivenStatus;
    protected double shipHeading = 0;
    private double wheelTurnAmount = 0;
    private boolean isMastRaised = true;
    private double mastProgress = 0;
    private byte sailAmount = 0;
    private double windBillowAmount;
    protected Image shipShape;
    private boolean isAnchorDrown = false;
    private double anchorProgress = 100; // 0 = fully down, 100 = fully up
    private boolean isActionBeingDone = false;
    protected String name;
    private ScheduledExecutorService anchorExecutor = Executors.newSingleThreadScheduledExecutor();
    private volatile boolean anchorTaskRunning = false;

    /**
     * Gives if the ship is currently alive or sunk
     * @return return true if ship is alive, false if sunk
     */
    public boolean isShipAlive() {
        return shipAlive;
    }

    /**
     * Gives ship's current X position
     * @return returns the ship's X position
     */
    public double getShipX() {
        return shipX;
    }

    /**
     * Gives ship's current Y position
     * @return returns the ship's Y position
     */
    public double getShipY() {
        return shipY;
    }

    public Point getShipPosition(){
        return new Point(shipX, shipY);
    }

    /**
     * Gives ship's current heading in degrees
     * @return returns the ship's heading (in degrees)
     */
    public double getShipHeading() {
        return shipHeading;
    }

    public double getWheelTurn() {
        return wheelTurnAmount;
    }

    /**
     * Gives ship's current health
     * @return returns the ship's current health
     */
    public double getShipHealthPercentage() {
        return shipHealth / MAX_HEALTH;
    }

    /**
     * Gives the ship's image for use on the canvas
     * @return returns the ship's image
     */
    public Image getShipShape() {
        return shipShape;
    }

    /**
     * Gives the name of the ship
     * @return returns the name of the ship
     */
    public String getName() {
        return name;
    }

    /**
     * Gives if the mast is currently raised or dropped
     * @return returns true if mast is raised, false if dropped
     */
    public boolean isMastRaised() {
        return isMastRaised;
    }

    /**
     * Sets ship's current X position
     * @param shipX the new X position
     */
    private void setShipX(double shipX) {
        this.shipX = shipX;
    }

    /**
     * Sets ship's current Y position
     * @param shipY the new Y position
     */
    private void setShipY(double shipY) {
        this.shipY = shipY;
    }

    /**
     * Sets the ship's current heading in degrees
     * @param shipHeading the new heading (in degrees)
     */
    public void setShipHeading(double shipHeading) {
        this.shipHeading = shipHeading;
    }

    /**
     * Sets the ship's current position
     * @param x the new X position
     * @param y the new Y position
     */
    public void setShipPosition(double x, double y) {
        setShipX(x);
        setShipY(y);
        this.shipShape.setCenter(this.shipX, this.shipY);
    }

    /**
     * Sets how much the ship's wheel is turned incrementally so that it takes time to turn the wheel
     * Caps it between -MAX_WHEEL_TURN and MAX_WHEEL_TURN
     * @param wheelDirection the direction to increment the wheel turn (-1 for left, 1 for right)
     */
    public void setWheelTurnAmount(int wheelDirection) { // TODO: something might be up here
        wheelTurnAmount += wheelDirection * WHEEL_TURN_SPEED;
        wheelTurnAmount = Math.max(-MAX_WHEEL_TURN, Math.min(wheelTurnAmount, MAX_WHEEL_TURN)); // clamping to the value

        if (wheelTurnAmount < -MAX_WHEEL_TURN || wheelTurnAmount > MAX_WHEEL_TURN) {
            System.out.println("Something weird happened with wheelTurnAmount in PlayerBoat. Look into this!!!");
        }
        System.out.println("Wheel Amount: " + wheelTurnAmount + ", Wheel Direction: " + wheelDirection);

    }

    /**
     * Updates the ship's heading based on the current wheel turn amount and ship turn speed
     * Caps it between 0 and 360 degrees
     */
    public void updateHeading() { // TODO: something might be up here along with setWheeelTurnAmount
        this.shipHeading += (this.wheelTurnAmount * this.SHIP_TURN_SPEED);
        if (this.shipHeading < 0) {
            this.shipHeading += 360;
        } else if (this.shipHeading >= 360) {
            this.shipHeading -= 360;
        }
    }

    /**
     * Calculates and the updates the ship's position based on its current velocity and heading
     * @return the change in previous position to current position as a Point 
     */
    public Point updatePosition() {
        double radians = Math.toRadians(this.shipHeading);

        double deltaX = this.shipVelocity * Math.cos(radians);
        double deltaY = this.shipVelocity * Math.sin(radians);

        setShipX(this.shipX + deltaX);
        setShipY(this.shipY + deltaY);
        // System.out.print("Player X velocity: " + deltaX + " ");
        // System.out.print("Player Y velocity: " + deltaY);
        // System.out.println("Toal Velocity: " + Math.sqrt(Math.pow(deltaX, 2) + Math.pow(deltaY, 2)));
        return(new Point(deltaX, deltaY));
    }

    /**
     * Updates the ship's velocity incrementally / decrementally to a certain cap based on the current ship status
     * Statuses include: sail amount, apparent wind, and mast status
     */
    public void updateShipVelocity(){ // TODO: test this and add code
        if (isAnchorDrown && shipVelocity > 0) { // if anchor is down, decelerate to 0
            shipVelocity -= ANCHOR_DECELERATION;
            return;
        }
        maxSpeedGivenStatus = MAX_SHIP_VELOCITY * // calculates max speed given the current circumstances
                              ((double) sailAmount / (double) MAX_SAIL_LENGTH) * 
                            //   ((double) windBillowAmount / (double) MAX_BILLOW_AMOUNT) *
                              (isMastRaised ? 1 : 0);
        // System.out.println("Max Speed Given Status: " + maxSpeedGivenStatus);
        // System.out.println("Sail Amount: " + sailAmount);
        // System.out.println("Velocity " + shipVelocity);
        // System.out.println("Is action being done?: " + isActionBeingDone);
        if (shipVelocity < maxSpeedGivenStatus) { // if less than max speed given circumstance, accelerate
            shipVelocity += ACCELERATION_INCREMENT;
            if (shipVelocity > maxSpeedGivenStatus) {
                shipVelocity = maxSpeedGivenStatus;
            }
        } else if (shipVelocity > maxSpeedGivenStatus) { // if more than max speed in given circumstances, decelerate to that
            shipVelocity -= FRICTION_INCREMENT;
            if (shipVelocity < maxSpeedGivenStatus) {
                shipVelocity = maxSpeedGivenStatus;
            }
        }
        // System.out.println("Current Speed: " + shipVelocity);
        // But I wonder if I should make it a sigmoid function -- if at 0 velocity, accelerate faster if sailAmount is at 100
    }

    public void raiseSail() { // TODO: test this
        if (isActionBeingDone) {
            return;
        }
        isActionBeingDone = true;
        if (isMastRaised) {
            if (sailAmount <= MAX_SAIL_LENGTH) {
                sailAmount -= SAIL_RAISE_SPEED;

                if (sailAmount < 0) {
                    sailAmount = 0;
                }
                isActionBeingDone = false;
                return;
            }
        } else {
            System.out.println("Mast is not raised, cannot raise sail!");
            isActionBeingDone = false;
            return;
        }
    }
    
    public void lowerSailOrRaiseMast() { // TODO: test this
        if (isActionBeingDone) {
            return;
        }
        isActionBeingDone = true;
        if (isMastRaised) {
            if (sailAmount <= MAX_SAIL_LENGTH) {
                sailAmount += SAIL_LOWER_SPEED;

                if (sailAmount > MAX_SAIL_LENGTH) {
                    sailAmount = MAX_SAIL_LENGTH;
                }
                isActionBeingDone = false;
                return;
            }
        } else { // raising mast; real question is if I want to add dropping mast if there is a delay
            if (mastProgress <= MAX_MAST_HEIGHT && mastProgress >= 0) {
                mastProgress += MAST_RAISE_SPEED;

                if (mastProgress >= MAX_MAST_HEIGHT) {
                    mastProgress = MAX_MAST_HEIGHT;
                    isMastRaised = true;
                }
                isActionBeingDone = false;
                return;
            }
        }
    }

    public void updateHoles(byte holeUpdate, boolean ifAddingHoles) {
        if (ifAddingHoles) {
            int emptyIndex = findIndex(shipHoles, (byte)0);
            if (emptyIndex != -1) {
                shipHoles[emptyIndex] = holeUpdate;
            } else {
                System.out.println("No space to add new hole in shipHoles array!");
            }
        } else {
            int index = findIndex(shipHoles, holeUpdate);
            if (index != -1) {
                shipHoles[index] = 0; // Remove by setting to 0
            } else {
                System.out.println(": Hole not found to remove in PlayerBoat (Not Good). Look into this!!!");
            }
        }
    }

    public void updateShipHealth() {
        short sum = 0;
        for (byte hole : shipHoles) {
            sum += hole;
        }
        this.shipHealth -= sum;
        if (this.shipHealth <= 0) {
            this.shipHealth = 0;
            killShip();
        }
    }

    public void setMastRaised(boolean isMastRaised) {
        this.isMastRaised = isMastRaised;
    }

    public void updateMastState(boolean isRaised) {
        this.isMastRaised = isRaised;
        if (isRaised) {
            this.shipVelocity = 0; // if mast is raised, ship can move
        } else if (!isRaised) {
           this.shipVelocity = 0; // if mast is lowered, ship cannot move
        } else {
            System.out.println("Something weird happened with isRaised boolean in PlayerBoat. Look into this!!!");
        }
    }

    /*
     * Sets the ship's status to be sunk (not alive)
     */
    public void killShip() {
        this.shipAlive = false;
    }

    /*
     * Buckets water out of the ship-- increasing the ship's health (not having it sink)
     */
    public void bucketShip() {
        this.shipHealth += MAX_BUCKET_AMOUNT;
    }

public void toggleAnchor() {
    if (anchorTaskRunning) return; // Prevent multiple tasks
    anchorTaskRunning = true;

    if (!isAnchorDrown) {
        anchorExecutor.scheduleAtFixedRate(() -> {
            dropAnchor();
            if (anchorProgress <= 0) {
                anchorTaskRunning = false;
                anchorExecutor.shutdownNow();
                anchorExecutor = Executors.newSingleThreadScheduledExecutor(); // Reset for next use
            }
        }, 0, 100, TimeUnit.MILLISECONDS); // adjust interval as needed
    } else {
        anchorExecutor.scheduleAtFixedRate(() -> {
            raiseAnchor();
            if (anchorProgress >= 100) {
                anchorTaskRunning = false;
                anchorExecutor.shutdownNow();
                anchorExecutor = Executors.newSingleThreadScheduledExecutor(); // Reset for next use
            }
        }, 0, 100, TimeUnit.MILLISECONDS);
    }
}

    public void dropAnchor() {
        // add incrementation (time for it to drop)
        anchorProgress -= ANCHOR_LOWER_SPEED;
        if (anchorProgress <= 0 && !isAnchorDrown) {
            anchorProgress = 0;
            isAnchorDrown = true;
        }
    }

    public void raiseAnchor() {
        anchorProgress += ANCHOR_LOWER_SPEED;
        if (anchorProgress >= 100 && isAnchorDrown) {
            anchorProgress = 100;
            isAnchorDrown = false;
        }
    }

    public double probabilityHitCannon(double distanceToTarget) {
        // base probability factor:
        // divide in to 4 ranges
        // if in 0-25% of max range, 85% chance to hit
        // if in 25-50% of max range, 60% chance to hit
        // if in 50-75% of max range, 35% chance to hit
        // if in 75-100% of max range, 15% chance to hit
        
        // shipSpin factor:
        // shipSpin should affect it by a sigmoid function, so that the more the ship is spinning, the less likely it is to hit
        // just multiply first probability by shipSpin probability

        // dialed in factor:
        // if just hit target, increase chance to hit by 10% (either multiply or add, not sure)
        // if hit twice consecutively, increase chance to hit by 20%
        // if hit three times consecutively, increase chance to hit by 25%

        // ON HIT
        // probably want to make another helper function for this
        // 1 - (mastProb + any other probabilities) = hit to the hull
        // mast
            // if match in heading OR they are orthagonal, then do 1 * probabilities below (which will be the base probabilities) 
                // so if dot product = floor(dot product)

            // differnece in speed should influence it too:
                // if matching speed, should be 1 * probabilities below, 
                // OR if one boat is anchored, should have pretty decent chance to hit mast
                // if either not met, shouldn't damper it too much (maybe 0.8 at most)
            // if up and within 1st range (really close), have much more control = 25% chance to hit mast
            // if down and within 1st range, make less probable to hit mast
            // if up 

            // have function that takes in speed of both ships, heading of both ships, and distance to target, and mast status of target ship, 
            // and find what is hit, and then adds that to the list of holes on the target ship
            // mast holes should always be tier 1.5 (2nd lowest in severity)
        return distanceToTarget;
    }

    /*
     * Scales the ship image by the SHIP_SCALE constant and a given scale factor (for zooming purposes)
     */
    public void scaleShipShape(double scaleFactor) {
        this.shipShape.setScale(SHIP_SCALE * scaleFactor);
    }

    private int findIndex(byte[] arr, byte value) {
        for (int i = 0; i < arr.length; i++) {
            if (arr[i] == value) {
                return i;
            }
        }
        return -1;
    }

}
