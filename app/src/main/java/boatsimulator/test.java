package boatsimulator;

import java.awt.Color;
import java.util.Random;

import edu.macalester.graphics.CanvasWindow;
import edu.macalester.graphics.Ellipse;
import edu.macalester.graphics.GraphicsGroup;
import edu.macalester.graphics.Image;
import edu.macalester.graphics.Line;
import edu.macalester.graphics.Point;

public class test {
    public static final short CANVAS_WIDTH = 1440;
    public static final short CANVAS_HEIGHT = 850;
    private static final double DEFAULT_GRID_SIZE = 700;
    private static final int NUM_CELLS = 26;
    public static final Point PLAYER_STARTING_POINT = new Point(CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2); // putting player in center of the screen
    private static final short ENEMY_SPAWN_DISTANCE = 550;

    public CanvasWindow canvas;
    private GraphicsGroup worldGroup;
    private PlayerBoat player;
    private SkeleShip enemy;
    private Image playerShip;
    private Image enemyShip;
    private Ellipse point;
    private Ellipse rock;
    private Random random;
    private double centeredPlayerPositionX;
    private double centeredPlayerPositionY;
    private short scrollX = 0;
    private short scrollY = 0;
    
    public test(PlayerBoat player, SkeleShip enemy){
        this.player = player;
        this.enemy = enemy;
        this.canvas = new CanvasWindow("Simulation", CANVAS_WIDTH, CANVAS_HEIGHT);
        this.worldGroup = new GraphicsGroup();
        this.playerShip = player.getShipShape();
        this.enemyShip = enemy.getShipShape();
        this.random = new Random();
        this.point = new Ellipse(PLAYER_STARTING_POINT.getX(), PLAYER_STARTING_POINT.getY(), 10, 10);
        this.rock = new Ellipse(0,0, 20, 20);
        point.setFillColor(Color.RED);
        point.setFilled(true);
        point.setStrokeColor(Color.RED);
        point.setStrokeWidth(1);

        this.canvas.setBackground(new Color(112, 130, 200, 255));
        setUpGridLines();
        canvas.add(worldGroup);
        
        canvas.add(playerShip, PLAYER_STARTING_POINT.getX(), PLAYER_STARTING_POINT.getY());
        canvas.add(point);
        player.setShipPosition(PLAYER_STARTING_POINT.getX(), PLAYER_STARTING_POINT.getY());
        playerShip.setCenter(PLAYER_STARTING_POINT);

        spawnEnemyRandomly();
        canvas.add(rock);

        playerShip.setRotation(player.getShipHeading());
        enemyShip.setRotation(enemy.getShipHeading());
        centeredPlayerPositionX = PLAYER_STARTING_POINT.getX() - player.getShipX();
        centeredPlayerPositionY = PLAYER_STARTING_POINT.getY() - player.getShipY();
    }

    /**
     * Adds grid lines to the canvas for better visualization of the gaming map.
     * Grid lines are spaced based on DEFAULT_GRID_SIZE and cover an area defined by NUM_CELLS.
     */
    private void setUpGridLines() {
        int halfCells = NUM_CELLS / 2;
        double startX = PLAYER_STARTING_POINT.getX() - halfCells * DEFAULT_GRID_SIZE;
        double endX = PLAYER_STARTING_POINT.getX() + halfCells * DEFAULT_GRID_SIZE;
        double startY = PLAYER_STARTING_POINT.getY() - halfCells * DEFAULT_GRID_SIZE;
        double endY = PLAYER_STARTING_POINT.getY() + halfCells * DEFAULT_GRID_SIZE;

        for (double i = startX; i <= endX; i += DEFAULT_GRID_SIZE) {
            makeGridLine(i, startY, i, endY);
        }
        for (double j = startY; j <= endY; j += DEFAULT_GRID_SIZE) {
            makeGridLine(startX, j, endX, j);
        }
    }

    /**
     * Creates a single grid line on the canvas and adds it to the world group.
     * @param x1 Beginning x coordinate of the line
     * @param y1 Beginning y coordinate of the line
     * @param x2 Ending x coordinate of the line
     * @param y2 Ending y coordinate of the line
     */
    private void makeGridLine(double x1, double y1, double x2, double y2) {
        Line line = new Line(x1, y1, x2, y2);
        line.setStrokeColor(Color.LIGHT_GRAY);
        line.setStrokeWidth(2);
        worldGroup.add(line);
    }

    /**
     * Spawns the enemy ship at a random location in a fixed circle around the player
     * Adds enemy ship to the world group and sets its initial position and heading (to face player)
     * 
     */
    private void spawnEnemyRandomly() {
        double randomRadians = random.nextDouble(0,2*Math.PI);
        System.out.println("Random number: " + randomRadians);
        Point enemySpawnPoint = new Point(PLAYER_STARTING_POINT.getX() + ENEMY_SPAWN_DISTANCE * Math.cos(randomRadians), PLAYER_STARTING_POINT.getY() + ENEMY_SPAWN_DISTANCE * Math.sin(randomRadians));
        worldGroup.add(enemyShip, enemySpawnPoint.getX(), enemySpawnPoint.getY());
        enemy.setShipPosition(enemySpawnPoint.getX(), enemySpawnPoint.getY());
        enemy.setShipHeading(Math.toDegrees(randomRadians) + 180); // 180 to face player
        enemyShip.setRotation(enemy.getShipHeading());
    }

    /**
     * Zooms the map in or out by scaling the world group and adjusting the player's ship size.
     * @param zoomFactor how much to scale the world (to give zoom effect)
     */
    public void doZoom(double zoomFactor) {
        this.worldGroup.setScale(zoomFactor);
        player.scaleShipShape(zoomFactor); // enemy ship doesn't need to be scaled because it's in the worldGroup which is being scaled
    }

    /**
     * Scrolls the map by adjusting the position of the world group and the player's ship.
     * Controlled by dragging the mouse.
     * @param deltaX scroll change in x direction
     * @param deltaY scroll change in y direction
     */
    public void doScroll(short deltaX, short deltaY) {
        scrollX += deltaX;
        scrollY += deltaY;
        worldGroup.setPosition(centeredPlayerPositionX + scrollX, centeredPlayerPositionY + scrollY);
        playerShip.setPosition(136 + scrollX, -97 + scrollY); // for some reason 136, -97 keep the player in place
    }

    /**
     * Rubberbands the map back to be centered on the player.
     * Controlled by pressing the space bar.
     */
    public void resetScroll() {
        scrollX = 0;
        scrollY = 0;
        worldGroup.setPosition(centeredPlayerPositionX + scrollX, centeredPlayerPositionY + scrollY);
        playerShip.setPosition(136 + scrollX, -97 + scrollY); // for some reason (136, -97) keep the player in place
    }
    
    /**
     * Animates the canvas with an anonymous function to update the display.
     * @param action the anonymous function to run
     */
    public void animate(Runnable action) {
        canvas.animate(action);
    }

    /*
     * Function that handles: 
     *  - Moving the world so the player stays centered
     *  - Rotating the player ship
     *  - Moving enemy ship relative to the player ship + its own movement
     */
    public void updateMap() {
        centeredPlayerPositionX = PLAYER_STARTING_POINT.getX() - player.getShipX();
        centeredPlayerPositionY = PLAYER_STARTING_POINT.getY() - player.getShipY();

        // Move the world so the player stays centered
        worldGroup.setPosition(centeredPlayerPositionX + scrollX, centeredPlayerPositionY + scrollY);
        worldGroup.setAnchor(player.getShipX(), player.getShipY());

        // Rotate the player ship image to match heading
        playerShip.setRotation(player.getShipHeading());

        // Draw the red point at the player's logical position (should now be at center)
        point.setPosition(PLAYER_STARTING_POINT); 
        rock.setPosition(player.getShipX(), player.getShipY());

        // System.out.println("Player Position: " + player.getShipX() + ", " + player.getShipY());
    }
}
