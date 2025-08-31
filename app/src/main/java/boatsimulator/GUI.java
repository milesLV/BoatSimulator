package boatsimulator;

import edu.macalester.graphics.GraphicsGroup;
import edu.macalester.graphics.GraphicsObject;
import edu.macalester.graphics.Image;

import java.awt.Color;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import edu.macalester.graphics.CanvasWindow;

public class GUI extends GraphicsGroup{
    final static byte PADDING = 15;
    final static byte WHEEL_ADJUSTMENT = 20;

    Image wheel;
    Image sail;
    Image shipHealth;
    PlayerBoat player;
    CanvasWindow canvas;
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
        List<GraphicsObject> images = Arrays.asList(wheel); // add all gui components here
        this.add(wheel);
        double totalWidth = 0;
        for (GraphicsObject img : images) {
            totalWidth += img.getWidth();
        }

        double horizontalAdjustment = totalWidth + PADDING * (images.size() + 1); //+ (allObjects + 1) * PADDING;

        canvas.add(this, canvas.getWidth() - horizontalAdjustment, canvas.getHeight() - 70);
    }

    public void updateGUIStates(){
        wheelTurn();
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
            int green = 255;
            int blue = (int)(255 * (1 - ratio));
            return new Color(red, green, blue);
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
        float COLOR_VIBRANCY = 1.1f;

        for (int i = 0; i < ARGB.length; i += 4) {
        float[] pixelARGB = new float[] {ARGB[i], ARGB[i + 1], ARGB[i + 2], ARGB[i + 3]};
        if (isTransparentPixel(pixelARGB)) {
            ARGB[i] = 0.0f; // make background transparent
        } else {
            for (int j = 0; j < 3; j++) { // R, G, B
                ARGB[i + 1 + j] = (RGB[j] * COLOR_VIBRANCY + ARGB[i + 1 + j]) / 2;
                }
            }
        }
        return new Image(wheelImage.getImageWidth(), wheelImage.getImageHeight(), ARGB, Image.PixelFormat.ARGB);
    }

    /**
     * Senses which pixels in the image are transparent / the background (98% successrate)
     * @param pixels the RGB components of the pixel that is currently under review
     * @return: if the pixel is transparent or not
     */
    private boolean isTransparentPixel(float[] pixelARGB){
        // pixelARGB[0] is the alpha channel (0.0 = fully transparent, 1.0 = fully opaque)
        return pixelARGB[0] < 0.1f;
    }

}
