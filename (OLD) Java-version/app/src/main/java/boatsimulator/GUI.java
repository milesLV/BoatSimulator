package boatsimulator;

import edu.macalester.graphics.GraphicsGroup;
import edu.macalester.graphics.GraphicsObject;
import edu.macalester.graphics.Image;
import edu.macalester.graphics.Path;
import edu.macalester.graphics.Point;
import edu.macalester.graphics.Rectangle;

import java.awt.Color;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import edu.macalester.graphics.CanvasWindow;

public class GUI extends GraphicsGroup{
    final static byte PADDING = 15;
    final static byte WHEEL_ADJUSTMENT = 20;
    final Point GUI_POSITION;

    Image wheel;
    Image sail;
    Image shipHealth;
    PlayerBoat player;
    CanvasWindow canvas;
    Rectangle waterLevel;
    /*
     * GUI
     *  Health bar (ship facing right profile view being filled up with water) (maybe add anchor to top right of this)
     *   - Text to show how many holes and how large
     *  Something to show anchor and mast status (maybe tack onto health bar?)
     *  Wheel turn (if all the way left = bright red, if all the way right = bright green, if in middle = black)
     *  Sail status (if all the way up = bright green, if all the way
     *  
     *  Something to show action in progress (like the sur.io progress bar) w/ seconds counting down in middle of screen
     *  Something quick and small to indicate that cannon hit (like actual SOT, also in the middle of the screen)
     *  Text to say that enemy mast is down
     */
    public GUI(PlayerBoat player, CanvasWindow canvas){
        this.player = player;
        this.canvas = canvas;
        this.wheel = new Image("wheelGUI.png");
        this.shipHealth = new Image("sloopHealthGUI.png");
        List<GraphicsObject> images = Arrays.asList(wheel, shipHealth); // add all gui components here

        // waterLevel = new Rectangle(0,0,0,0);

        shipHealth.setScale(0.25);
        this.add(wheel,0, -wheel.getHeight());
        this.add(shipHealth, -3.2*wheel.getWidth() + PADDING, -shipHealth.getHeight() * 0.515);
        double totalWidth = 0;
        for (GraphicsObject img : images) {
            totalWidth += img.getWidth() * img.getScaleX();
        }

        double horizontalAdjustment = totalWidth + PADDING * (images.size() + 1);
        GUI_POSITION = new Point(canvas.getWidth() - horizontalAdjustment, canvas.getHeight() - 70);
        canvas.add(this, GUI_POSITION.getX(), GUI_POSITION.getY());
    }

    public void updateGUIStates(){
        wheelTurn();
        updateShipHealth();
    }

    private void wheelTurn(){
        this.remove(wheel);
        double wheelTurn = player.getWheelTurn() + WHEEL_ADJUSTMENT;

        Color wheelColor = getWheelColor(wheelTurn);
        this.wheel = tintWheelImage(wheelColor, wheel);
        this.wheel.setRotation(wheelTurn);
        this.add(wheel);
    }

    private Color getWheelColor(double wheelTurn) {
        // Clamp wheelTurn between -360 and 360
        wheelTurn = Math.max(-360, Math.min(360, wheelTurn));
        if (wheelTurn < 0) {
            // Red to White
            float ratio = (float)((wheelTurn + 360f) / 360f); // -360 -> 0: 0 -> 1
            ratio = Math.max(0f, Math.min(1f, ratio));
            int red = 255;
            int green = (int)(255 * ratio);
            int blue = (int)(255 * ratio);
            return new Color(red, green, blue);
        } else {
            // White to Green
            float ratio = (float)(wheelTurn / 360f); // 0 -> 360: 0 -> 1
            ratio = Math.max(0f, Math.min(1f, ratio));
            int red = (int)(255 * (1 - ratio));
            int blue = (int)(255 * (1 - ratio));
            return new Color(red, 255, blue);
        }
    }

    /**
     * Applies a color tint to the wheel image and makes the background transparent.
     * @param color The color to apply as a tint to the wheel
     * @param wheelImage The image of the wheel
     * @return A new Image with the tint applied + transparent background
     */
    private Image tintWheelImage(Color color, Image wheelImage) {
        float[] ARGB = wheelImage.toFloatArray(Image.PixelFormat.ARGB);
        float[] RGB = color.getComponents(null);
        float COLOR_VIBRANCY = 0.95f;

        for (int i = 0; i < ARGB.length; i += 4) {
        float[] pixelARGB = new float[] {ARGB[i], ARGB[i + 1], ARGB[i + 2], ARGB[i + 3]};
        if (pixelARGB[0] < 0.1f) {
            ARGB[i] = 0.0f; // make background transparent by making all nearly-transparent pixels fully transparent
        } else {
            for (int j = 0; j < 3; j++) { // R, G, B
                ARGB[i + 1 + j] = (RGB[j] * COLOR_VIBRANCY + ARGB[i + 1 + j]) / 2;
                }
            }
        }
        return new Image(wheelImage.getImageWidth(), wheelImage.getImageHeight(), ARGB, Image.PixelFormat.ARGB);
    }

    private void updateShipHealth() {
        // this.remove(waterLevel);
        double health = 0;
        // System.out.println(GUI_POSITION);
        waterLevel = new Rectangle(1.7*wheel.getWidth(), //  +  +  
                                   20,  // +  + 
                                   shipHealth.getWidth() * shipHealth.getScaleX(), 
                                   shipHealth.getHeight() /2 * shipHealth.getScaleY() * health
                                   );
        // Path path = new Path(null, false); // get CoPilot's help with this but steps:
        /*
         * Goal is to first find the "corners" of boat -- top left, bottom left, top right, bottom right
         * Then find slope of left and find function that works with right
         * Then, make function that takes in y from health and # of points to interpolate and calculates y = mx + b and y = ab^x
         * and then iterpolates along that with # of points
         * Might be a bit of a headache but I think it would be cool
         */
        waterLevel.setFillColor(new Color(253, 0, 0, 0));
        waterLevel.setFilled(true);
        // this.add(waterLevel);

    }

}
