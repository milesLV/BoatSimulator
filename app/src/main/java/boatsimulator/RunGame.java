package boatsimulator;

import java.util.HashMap;
import edu.macalester.graphics.Point;

public class RunGame{
    private static double ZOOM_INCREMENT = 0.1;
    private final double MAX_ZOOM_LIMIT = 2.50;
    private final double MIN_ZOOM_LIMIT = 0.6;

    private test map;
    private PlayerBoat player;
    private SkeleShip enemy;
    private GUI gui;

    private double currentZoom = 1.6;

    public RunGame() {
        this.player = new PlayerBoat();
        this.enemy = new SkeleShip();
        this.map = new test(player, enemy);
        this.gui = new GUI(player, map.canvas);

        // map.addToMap(player.getShipShape());
        // map.addToMap(enemy.getShipShape());
        
        // player.setShipPosition((double) GamingMap.CANVAS_WIDTH / 2, (double) GamingMap.CANVAS_HEIGHT / 2);
        // enemy.setShipPosition((double) GamingMap.CANVAS_WIDTH / 2 + 100, (double) GamingMap.CANVAS_HEIGHT / 2);

        map.canvas.onKeyDown(event -> controls(event.getKey().toString(), new Point(0,0)));
        map.canvas.onDrag(event2 -> controls(event2.getClass().getSimpleName(), event2.getDelta()));
        map.canvas.onClick(event3 -> controls(event3.getClass().getSimpleName(), event3.getPosition()));
        zoom(currentZoom); // setting initial zoom level
        gameOperation();
    }

    /**
     * 
     * Main game loop function
     * Updates player and enemy boat positions, headings, and velocities and updates the map accordingly.
     * 
     */
    public void gameOperation(){
        /* Loop function
        * Update player boat (heading and velocity)
        * Update enemy boat (heading and velocity)
        * Update map
            - Update wind direction
        * Check if other ship is in triangle and fire cannons
            - Add holes to lists if successful
        * Subtract health depending on holes (shipHoles has indices of rate of water:)
        
        * Hard part: if doing one action, can't do another action until first action is done
        * Harder part: How does the AI actually put up a good fight?
        */
        map.animate(() -> {
            // for(int i = 0; i < 10; i++){
                player.updateHeading();
                player.updateShipVelocity();
                player.updatePosition();
                gui.updateGUIStates();

                // enemy.updateHeading();
                // enemy.updateShipVelocity();
                // enemy.updatePosition();
                map.updateMap();
                // try {
                //     Thread.sleep(1000);
                // } catch (InterruptedException e) {
                //     // TODO Auto-generated catch block
                //     e.printStackTrace();
                // }
            // }
        });
    }

    /**
     * Gives the player the ability to control
     * @param key the key that was pressed
     * @param position the position of the mouse when pressed (mouse events only)
     * 
     */
    private void controls(String key, Point position) {
        HashMap<String, Runnable> controlMap = new HashMap<>();

        controlMap.put("A", () -> player.setWheelTurnAmount(-1));
        controlMap.put("D", () -> player.setWheelTurnAmount(1));
        controlMap.put("LEFT_ARROW", () -> player.setWheelTurnAmount(-1));
        controlMap.put("RIGHT_ARROW", () -> player.setWheelTurnAmount(1));

        controlMap.put("W", () -> player.raiseSail());
        controlMap.put("S", () -> player.lowerSailOrRaiseMast());
        controlMap.put("UP_ARROW", () -> player.raiseSail());
        controlMap.put("DOWN_ARROW", () -> player.lowerSailOrRaiseMast());

        controlMap.put("X", () -> player.toggleAnchor());
        // controlMap.put("B", () -> player.bucketWater());
        // controlMap.put("R", () -> player.repairHole());
        // controlMap.put("M", () -> player.repairMast());
        // controlMap.put("H", () -> hideCannonRanges()) // if press H, the triangles for the cannons are hidden and it's just the boat shown on the map

        controlMap.put("Q", () -> zoom(1));
        controlMap.put("E", () -> zoom(-1));
        controlMap.put("SPACE", () -> map.resetScroll());

        // controlMap.put("MouseButtonEvent", () -> { // maybe for identifying stuff? Or this can be for resetting scroll

        // })
        controlMap.put("MouseMotionEvent", () -> {
            short deltaX = (short) position.getX();
            short deltaY = (short) position.getY();
            System.out.println("Delta X: " + deltaX + ", Delta Y: " + deltaY);
            map.doScroll(deltaX, deltaY);
        });

        if (controlMap.containsKey(key)) {
            controlMap.get(key).run();
        }
    }

    /**
     * Connects the controls to the zooming feature of the map
     * @param zoomIn the direction to zoom in (1 for zoom in, -1 for zoom out)
     */
    public void zoom(double zoomIn) {
        double previousZoom = currentZoom;
        currentZoom += zoomIn * ZOOM_INCREMENT;
        if (currentZoom > MAX_ZOOM_LIMIT || currentZoom < MIN_ZOOM_LIMIT) { // setting bounds for zoom
            currentZoom = previousZoom; // resetting to original level
        }
        
        // enemy.setShipPosition(translationX, translationY);
        map.doZoom(currentZoom);
    }
}

    // List of actions that can be done without wait:
    /*
    * Turn wheel
    * Raise / lower sail
    * Drop anchor
    */

    // List of actions that have a wait time:
    /*
    * RUN BACK TO WHEEL (dependent: bucket/patch = 1.5, raise mast / anchor = 0.1)
    * Bucket water (1 second wait)
    * Patch hole (amount of time dependent on size of hole)
    * Raise mast (9 seconds)
    * Patch mast (tier 2 hole)
    * Raise anchor (5 seconds)
    */


    // FUTURE MAYBE ADDITIONS:
    /*
    * Wind direction and speed (affects ship speed and turning radius)
    * Boarding mechanics:
    *   Either probability of success of boarding or make a system where camera centers on a large dot (the player) 
    *   and you can control the dot with WASD and control the boat with arrow keys (shift to swim faster, d to dive with makes
        probability of boarding lower but lowers probability of being seen (which increases failing to take over enemy ship)),
        dying may be hard to do because 30 seconds wait but assumption is doing doubles (this can change?)
    *
    * Different ship types (brigs, galleons, etc)
    *
    * More complex AI behavior (evasive maneuvers, coordinated attacks)
    * 
    */