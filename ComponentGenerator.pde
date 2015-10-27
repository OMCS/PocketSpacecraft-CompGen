/* PocketSpacecraft.com Component Generator v0.6 - Oliver Saunders (ols7@aber.ac.uk) - August / September 2014
This software uses parametric design to generate component designs in accordance with user-supplied constraints

Major Revisions:

0.1 - First version (13th August 2014)
0.2 - Changed measurements to microns, new object-oriented architecture, checked measurements (13th August 2014)
0.3 - Removed some hard-coded numbers, changed vertical / horizontal lines to rectangles, added remaining pins (14th August 2014)
0.3a - Uploaded to Git. Provided parameter to label pins, started conversion of 45 degree lines to rectangles (14th August 2014)
0.4 - Changed to centre based coordinate system for pins. Improvements to 45 degree lines, still work to do. Testing and fixing equations for different inputs (22nd August 2014)
v0.4a - Added beginnings of SVG generation code, fixed some parameter bugs, added image output for viewing on screen of any resolution, cleaned up some equations (25th August 2014)
v0.5 - New traces, readability improvements, added ability to store previous feature (used for area calculations), rationalised coordinate system to centers, started implementing circular end caps (28th August 2014)
v0.5a - Finished implementing all traces, fixed equations, started on circular end caps. Need to work on fixing 45 degree traces, end caps and area calculations (30th August 2014)
v0.5b - Fixed 45 degree traces and added end caps, implemented detector area calculations (2nd September 2014)
v0.6 - Implemented area and centre of mass calculations, requires testing (4th / 5th September 2014)

To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights 
to this software to the public domain worldwide. This software is distributed without any warranty.
You should have received a copy of the CC0 Public Domain Dedication along with this software. 
If not, see http://creativecommons.org/publicdomain/zero/1.0/.

TODO: Test area and centre of mass calculations

See documentation for further information

*/

import java.text.DecimalFormat; // Used to define precision for SVG values and print results of calculations using standard (not scientific) notation

/* Data structure to store Features */
ArrayList<Feature> featuresInDevice;

/* Input parameters (measurements in microns currently, units can be adjusted during conversion to SVG) */
/* For information on these variables please consult the documentation */
private boolean ENABLE_DAISYCHAIN = true;
private boolean ENABLE_TERMINATION = true;
private boolean ENABLE_PIN_LABELS = true;
private boolean MAXIMISE_DETECTION_AREA = false; // XXX: Not yet implemented
private boolean ENABLE_CIRCULAR_END_CAPS = true; 
private boolean ENABLE_DETECTOR_TEST_PADS = false; // XXX: Not yet implemented
private boolean HIGHLIGHT_DETECTOR_AREA = true;
private boolean HIGHLIGHT_DEVICE_CENTER = true;

private float PIN_DIAMETER = 400;
private float PIN_SPACING = 400;
private float MINIMUM_FEATURE_SIZE = 100;
private float TRACE_DISTANCE_FROM_EDGE = 100;
private float DEVICE_AREA = 10000;
private float DEVICE_CENTER = DEVICE_AREA / 2;
private float DEFAULT_TRACE_WIDTH = 100;
 
private float DETECTOR_WIDTH = 7300;
private float DETECTOR_HEIGHT = 7300;
private float DETECTOR_SPACING = MINIMUM_FEATURE_SIZE;

// Colours for various elements
private final color DEFAULT_COLOR = color(0,0,0); // Black
private final color END_CAP_COLOR = color(DEFAULT_COLOR); 
//private final color END_CAP_COLOR = color(204,102,0); // Orange
private final color PIN_COLOR = color(0,100,0); // Light Green
private final color INVERSE_COLOR = color(255,255,255); // White
private final color ERROR_COLOR = color(255,0,0); // Red

// Interactive mode - prevents application exit after generating output
private final boolean ENABLE_INTERACTIVE_MODE = true;

/* SVG output Constants and structures */

// Scaling factor for conversion between microns and mm - represents how many microns are in a milimetre
private final float SVG_SCALING_FACTOR = 1000;

// SVG header and footer
private final String SVG_HEADER = "<svg height='" + DEVICE_AREA/1000 + "mm' width='" + DEVICE_AREA/1000 + "mm'>";
private final String SVG_FOOTER = "</svg>";

// SVG display settings
private final String SVG_STROKE_COLOUR  = "'black'"; // Embedded single quotes make later string concatenation simpler
private final String SVG_STROKE_WIDTH = "'0.100'";
private final String SVG_FILL_COLOR = "'black'"; 

// Set SVG Precision - default is to 3 decimal places
DecimalFormat SVGPrecision = new DecimalFormat("0.000");

// Output directory and structure for storing SVG output - note the trailing slash, this is REQUIRED
private final String SVG_OUTPUT_DIRECTORY = "/Users/Ollie/Desktop/"; // XXX: Change this before use
private final StringBuilder sbSVGOutput = new StringBuilder();

/* Area and centre of mass calculation variables */
private double dTotalCalculatedArea = 0;
private double dDetectorTraceArea = 0;

private double dOverallMass = 0; // Keeps track of overall mass in grams

// These variables store the current overall moment in 3 dimensions 
private double dOverallMomentX = 0; 
private double dOverallMomentY = 0;
private double dOverallMomentZ = 0;

private final int SUBSTRATE_THICKNESS = 5; // Kapton substrate assumed to be 5 microns thick
private final int TRACE_DENSITY = 10490000; // Material assumed to be silver, given in grams per cubic *metre* 
private final int TRACE_THICKNESS = 10; // Trace assumed to be 10 microns thick

// Enable full screen if running interactively
boolean sketchFullScreen() 
{
  if (ENABLE_INTERACTIVE_MODE)
  {
    return true;

  }
  else
  {
      return false;
  }
}

/* Feature superclass */
public abstract class Feature
{ 
  /* All features will keep track of their area, mass and the previous feature */
  protected double dFeatureArea;
  protected double dFeatureMass; 
  protected Feature previousFeature;
  
  /* Keeps track of the previous feature, can pass previous feature in via constructor or by calling this method */
  protected void setPreviousFeature(Feature previousFeature)
 {
  this.previousFeature = previousFeature;
 } 

  protected void setFeatureArea(double dFeatureArea)
  {
    this.dFeatureArea = dFeatureArea; // Sets area in terms of square microns, will require conversion later
    
    dTotalCalculatedArea += dFeatureArea;
  }

  /* Method to draw features
   * Implementation differs depending on feature type
   */
  protected abstract void drawFeature();

  /* Method to return an SVG representation of the feature, differs depending on type */
  protected abstract String generateSVG();
}

public final class Pin extends Feature
{
  public float fXPosition, fYPosition, fDiameter;
  public String[] sLabelText;

   // Constructor for drawing circular components (pins, vias, etc) with optional labelling 
   Pin(float fXPosition, float fYPosition, float fDiameter, Feature previousFeature, String... sLabelText)
   {
     this.fXPosition = fXPosition;
     this.fYPosition = fYPosition;
     this.fDiameter = fDiameter;

     this.previousFeature = previousFeature;
      
     this.sLabelText = sLabelText; 

     // Circle area = PI*(r^2)
     super.setFeatureArea(PI* ( (PIN_DIAMETER/2) * (PIN_DIAMETER/2))); 
   }

  @Override
  protected void drawFeature()
  {
    fill(PIN_COLOR);
    ellipse(this.fXPosition, this.fYPosition, PIN_DIAMETER, PIN_DIAMETER);
    fill(DEFAULT_COLOR);

    // Add labels if requested
    if (ENABLE_PIN_LABELS && this.sLabelText[0] != "")
    {
      fill(INVERSE_COLOR);
      text(this.sLabelText[0], this.fXPosition, this.fYPosition);
      fill(DEFAULT_COLOR);
    }

    /* Centre of mass calculations for Pins */

    // Calculate distance from centre point - all results given in metres, very small numbers
    double fXDistanceFromCenter = Math.abs(this.fXPosition - DEVICE_CENTER) / 1000000; // Microns -> Metres
    double fYDistanceFromCenter = Math.abs(this.fYPosition - DEVICE_CENTER) / 1000000;
    double fZDistanceFromCenter = (SUBSTRATE_THICKNESS / 2) + (TRACE_THICKNESS / 2) / 1000000; // Z centre assumed to be half substrate thickness plus half trace thickness, result given in metres

     /* Calculate the mass of the Pin, pins assumed to be cylindrical 
      * 2D Area = PI*(r^2)
      * Volume = (Area) * Height
      * Mass = Density * Volume
      */

    // Product of density and volume. Area converted to square metres, height (thickness) converted to metres, density already given in grams per cubic metre
    this.dFeatureMass = ((this.dFeatureArea / 1000000000000L * TRACE_THICKNESS / 1000000) * TRACE_DENSITY);
   
   dOverallMass += this.dFeatureMass; // Add to running total of mass 

    // Calculate Moment using distance x mass
    double dXMoment = this.dFeatureMass * fXDistanceFromCenter;
    double dYMoment = this.dFeatureMass * fYDistanceFromCenter;
    double dZMoment = this.dFeatureMass * fZDistanceFromCenter;

    // Add to running total
    dOverallMomentX += dXMoment;
    dOverallMomentY += dYMoment;
    dOverallMomentZ += dZMoment;
  }

  @Override
  protected String generateSVG()
  {
    return "<circle cx='" + SVGPrecision.format(fXPosition / SVG_SCALING_FACTOR) + "mm' cy='" + SVGPrecision.format(fYPosition / SVG_SCALING_FACTOR) + 
    "mm' r='" + (PIN_DIAMETER / SVG_SCALING_FACTOR) / 2 + "mm' fill=" + SVG_FILL_COLOR + " />"; 
  }
}

public final class Trace extends Feature
{
  public float fXStart, fYStart, fWidth, fHeight, fXEnd, fYEnd;
  public float fXCenter, fYCenter;
  public String sTraceType;

 // Constructor for drawing traces
  public Trace(float fXStart, float fYStart, float fWidth, float fHeight, Feature previousFeature, String sTraceType)
  {
    this.fXStart = fXStart;
    this.fYStart = fYStart;
    this.fWidth = fWidth;
    this.fHeight = fHeight;
    this.sTraceType = sTraceType;
    
    this.previousFeature = previousFeature;
    
    this.fXCenter = (fXStart + fXEnd) / 2;
    this.fYCenter = (fYStart + fYEnd) / 2;

    if (sTraceType == "VTRACE")
    {
      this.fXEnd = this.fXStart + DEFAULT_TRACE_WIDTH;
      this.fYEnd = this.fYStart + (this.fHeight - this.fYStart);
    }
    else if (sTraceType == "HTRACE")
    {
      this.fXEnd = this.fXStart + (this.fWidth - this.fXStart);
      this.fYEnd = this.fYStart + this.fHeight;
    }

  }

  @Override
  protected void drawFeature()
  {
    if (sTraceType == "VTRACE") // Vertical Traces
    { 
      if (ENABLE_CIRCULAR_END_CAPS)
      {
          if (this.fYEnd < this.fYStart)
          {
              rect(this.fXStart - (DEFAULT_TRACE_WIDTH / 2), this.fYStart, DEFAULT_TRACE_WIDTH, (this.fHeight - this.fYStart) + DEFAULT_TRACE_WIDTH);
              fill(END_CAP_COLOR);
              ellipse(this.fXStart, this.fHeight + DEFAULT_TRACE_WIDTH, DEFAULT_TRACE_WIDTH, DEFAULT_TRACE_WIDTH);
              fill(DEFAULT_COLOR);
          }
          else
          {
              rect(this.fXStart - (DEFAULT_TRACE_WIDTH / 2), this.fYStart, DEFAULT_TRACE_WIDTH, (this.fHeight - this.fYStart));
              fill(END_CAP_COLOR);
              ellipse(this.fXStart, this.fHeight, DEFAULT_TRACE_WIDTH, DEFAULT_TRACE_WIDTH);
              fill(DEFAULT_COLOR);
          }

          /*arc(this.fXStart, this.fHeight - DEFAULT_TRACE_WIDTH / 2, DEFAULT_TRACE_WIDTH, DEFAULT_TRACE_WIDTH, 0, PI);*/
      }

      else
      {
          rect(this.fXStart - (DEFAULT_TRACE_WIDTH / 2), this.fYStart, DEFAULT_TRACE_WIDTH, (this.fHeight - this.fYStart));
      }

     /* Area calculations for vertical traces */
     /* TODO: Test this */
      if (this.previousFeature instanceof Pin) // If the previous feature was a Pin
      {
        Pin PF = (Pin) previousFeature; // Cast previous feature type to Pin
        super.setFeatureArea(DEFAULT_TRACE_WIDTH * this.fHeight - (PF.fYPosition + PIN_DIAMETER / 2)); // Subtract the overlapping area from the calculation
      }

      else if (this.previousFeature instanceof Trace) // Otherwise it must have been a Trace
      {
        Trace PF = (Trace) previousFeature; // Cast to Trace
        super.setFeatureArea(DEFAULT_TRACE_WIDTH * this.fHeight - (DEFAULT_TRACE_WIDTH / 2)); // Width * height minus the overlap
      }
    }
  
    else if (sTraceType == "HTRACE") // Horziontal Traces
    {    
      if (ENABLE_CIRCULAR_END_CAPS)
      {
        rect(this.fXStart, this.fYStart - (DEFAULT_TRACE_WIDTH / 2), this.fWidth - this.fXStart - (DEFAULT_TRACE_WIDTH / 2), DEFAULT_TRACE_WIDTH);
        fill(END_CAP_COLOR);
        ellipse(this.fWidth - (DEFAULT_TRACE_WIDTH / 2), this.fYStart, DEFAULT_TRACE_WIDTH, DEFAULT_TRACE_WIDTH);
        fill(DEFAULT_COLOR);
      }

      else
      {
        rect(this.fXStart, this.fYStart - (DEFAULT_TRACE_WIDTH / 2), this.fWidth - this.fXStart - (DEFAULT_TRACE_WIDTH / 2), DEFAULT_TRACE_WIDTH); 
      }

      /* Area Calculations for Horizontal Traces
      /* TODO: Test this */
      if (this.previousFeature instanceof Pin) // If the previous feature was a Pin the next feature must also be a Pin
      {
        Pin PF = (Pin) previousFeature; // Cast previous feature type to Pin
        super.setFeatureArea(this.fWidth * DEFAULT_TRACE_WIDTH - (PIN_DIAMETER / 2)); // Subtract the overlapping area from the calculation
      }

      else if (this.previousFeature instanceof Trace) // Otherwise it must have been a Trace
      {
        Trace PF = (Trace) previousFeature; // Cast to Trace
        super.setFeatureArea(DEFAULT_TRACE_WIDTH * this.fHeight - (DEFAULT_TRACE_WIDTH / 2)); // Width * Height minus the overlap
      }
    }
  
    else if (sTraceType.contains("45")) // 45 Degree Traces
    {
      // Calculations for 45 degree traces
      float fCalculatedTraceAreaWidth = (this.fWidth - this.fXStart);
      float fCalculatedTraceAreaHeight = (this.fHeight - this.fYStart);
      float fCalculatedTraceLength =  (this.fHeight - this.fYStart) * sqrt(2); // Pythagorean constant 
  
      if (Math.abs(fCalculatedTraceAreaHeight) != Math.abs(fCalculatedTraceAreaWidth)) // Absolute value, positive number
      {
        /* If the trace isn't at a 45 degree angle, display a rectangle over the area - failure mode */
        fill(ERROR_COLOR);
        rect(this.fXStart, this.fYStart, 200, 200);
        fill(DEFAULT_COLOR);

        // Display calculated values if the trace isn't at 45 degrees
        textSize(150);
        fill(INVERSE_COLOR);
        //text("Height: " + fCalculatedTraceAreaHeight + " Width: " + fCalculatedTraceAreaWidth, this.fXStart + 200, this.fYStart);
        println("Height: " + fCalculatedTraceAreaHeight + " Width: " + fCalculatedTraceAreaWidth + "\n"); 
        fill(DEFAULT_COLOR);
      }
      
      else // Correct 45 degree trace, set feature area
      {
        super.setFeatureArea(Math.abs(fCalculatedTraceAreaWidth) * Math.abs(fCalculatedTraceAreaHeight));
      }

      pushMatrix();
        translate(this.fXStart + fCalculatedTraceAreaWidth / 2, this.fYStart + fCalculatedTraceAreaHeight / 2 ); // New origin is at object centre

        if (this.sTraceType == "45ATRACE")
        {
          rotate(radians(-45));
        }
        else
        {
          rotate(radians(45));
        }

        rect(-DEFAULT_TRACE_WIDTH / 2, -fCalculatedTraceLength / 2, DEFAULT_TRACE_WIDTH, fCalculatedTraceLength);
        //ellipse(-DEFAULT_TRACE_WIDTH / 2, -fCalculatedTraceLength / 2, 100, 100);
        fill(END_CAP_COLOR);
        ellipse(-DEFAULT_TRACE_WIDTH / 2  + 50, fCalculatedTraceLength / 2, DEFAULT_TRACE_WIDTH, DEFAULT_TRACE_WIDTH);
        fill(DEFAULT_COLOR);
      popMatrix();
    }   

    /* Centre of mass calculations for Traces */

    // Calculate distance from centre point - all results given in metres, very small numbers
    double fXDistanceFromCenter = Math.abs(this.fXCenter - DEVICE_CENTER) / 1000000; // Microns -> Metres
    double fYDistanceFromCenter = Math.abs(this.fYCenter - DEVICE_CENTER) / 1000000;
    double fZDistanceFromCenter = (SUBSTRATE_THICKNESS / 2) + (TRACE_THICKNESS / 2) / 1000000; // Z centre assumed to be half substrate thickness plus half trace thickness, result given in metres

     /* Calculate the mass of the trace, trace assumed to be a cuboid
      * Area= Length * Width
      * Volume = (Area) * Height
      * Mass = Density * Volume
      */

    // Product of density and volume. Area converted to square metres, height (thickness) converted to metres, density already given in grams per cubic metre
    // Mass should therefore be in grams
    this.dFeatureMass = ((this.dFeatureArea / 1000000000000L * TRACE_THICKNESS / 1000000) * TRACE_DENSITY);
    dOverallMass += this.dFeatureMass; // Add to overall mass count  

    // Calculate Moment using distance x mass
    double dXMoment = this.dFeatureMass * fXDistanceFromCenter;
    double dYMoment = this.dFeatureMass * fYDistanceFromCenter;
    double dZMoment = this.dFeatureMass * fZDistanceFromCenter;

    // Add to running total
    dOverallMomentX += dXMoment;
    dOverallMomentY += dYMoment;
    dOverallMomentZ += dZMoment;
  }

  protected String generateSVG()
  { 
    return "";
  }
}

public class Detector extends Feature
{
  /* Variables to store position and calculate number of traces for detector area */
  private float fCurrentX, fCurrentY; // Values to draw detector traces at
  private int numberOfVerticalTraces = ceil( (DETECTOR_WIDTH / DETECTOR_SPACING) / 2); // Calculate the number of vertical traces which can fit in the detector area
  private int numberOfHorizontalTracePairs = floor( (DETECTOR_WIDTH / 2) / 2) / 100; // Calculate the number
    
  /* Detector constructor, keep track of starting coordinates */
  public Detector()
  {
    this.fCurrentX = (DEVICE_AREA / 2) - (DETECTOR_WIDTH / 2) + (DEFAULT_TRACE_WIDTH / 2);
    this.fCurrentY = (DEVICE_AREA / 2) - (DETECTOR_HEIGHT / 2);
  }  

  @Override
  protected void drawFeature()
  {    
    // Show detector area 
    if (HIGHLIGHT_DETECTOR_AREA)
    {
      rectMode(CENTER);
      fill(INVERSE_COLOR);
      rect(DEVICE_AREA / 2, DEVICE_AREA / 2, DETECTOR_WIDTH, DETECTOR_HEIGHT);
      fill(DEFAULT_COLOR);
      rectMode(CORNER);
    }

    boolean previousValue = ENABLE_CIRCULAR_END_CAPS; // Save value of boolean
    ENABLE_CIRCULAR_END_CAPS = false; // Disable circular end caps on horizontal traces

    /* Create required number of horizontal traces depending on parameters */
    for (int currentTrace = 0; currentTrace < numberOfHorizontalTracePairs; currentTrace++) 
    {     
      /* Set vertical position to the bottom of the detector area */
      this.fCurrentY = (DEVICE_AREA / 2) + (DETECTOR_HEIGHT / 2) - (DEFAULT_TRACE_WIDTH / 2);

      // Create the trace that links at the bottom
      Trace detectorHorizontal = new Trace(this.fCurrentX,
      fCurrentY,
      this.fCurrentX + DETECTOR_SPACING + DEFAULT_TRACE_WIDTH,
      DEFAULT_TRACE_WIDTH,       
      null, "HTRACE"); // Not storing previous trace, area calculations handled in dedicated function

      if (currentTrace != numberOfHorizontalTracePairs)
      {
        detectorHorizontal.drawFeature(); // Draw the bottom linking trace
      }

      this.fCurrentX += (DETECTOR_SPACING + DEFAULT_TRACE_WIDTH); // Leave the required spacing between horizontal traces

      /* Set vertical position to the top of the detector area */
      this.fCurrentY = (DEVICE_AREA / 2) - (DETECTOR_HEIGHT / 2) + (DEFAULT_TRACE_WIDTH / 2);

      /* Create the trace that links at the top */
      detectorHorizontal = new Trace(this.fCurrentX - DEFAULT_TRACE_WIDTH,
        this.fCurrentY,
        this.fCurrentX + DETECTOR_SPACING + DEFAULT_TRACE_WIDTH,
        DEFAULT_TRACE_WIDTH,       
        null, "HTRACE"); 

      detectorHorizontal.drawFeature(); // Draw the top linking trace
      this.fCurrentX += (DETECTOR_SPACING + DEFAULT_TRACE_WIDTH); // Leave the required spacing between horizontal traces
    } 

    this.fCurrentX = (DEVICE_AREA / 2) - (DETECTOR_WIDTH / 2); // Reset X Position 
    this.fCurrentY = (DEVICE_AREA  / 2) - (DETECTOR_HEIGHT / 2); // Reset Y Position

    Trace detectorVertical; // Initialise this trace

    /* Create required number of vertical traces depending on the parameters */ 
    for (int currentTrace = 0; currentTrace < numberOfVerticalTraces; currentTrace++)
    {
      // Create vertical traces

      if (currentTrace % 2 == 0) // Trace runs from bottom to top
      {
          detectorVertical = new Trace(this.fCurrentX,
            this.fCurrentY,
            DEFAULT_TRACE_WIDTH,
            this.fCurrentY + DETECTOR_HEIGHT,
            null, "VTRACE");
      }

      else
      {
        detectorVertical = new Trace(this.fCurrentX,
          this.fCurrentY + DETECTOR_HEIGHT,
          DEFAULT_TRACE_WIDTH,
          this.fCurrentY,
          null, "VTRACE");
      }
      
      /* Draw the vertical trace */
      detectorVertical.drawFeature();
      
      // Leave space of DETECTOR_SPACING between vertical traces
      this.fCurrentX += (DETECTOR_SPACING + DEFAULT_TRACE_WIDTH);

    }

    ENABLE_CIRCULAR_END_CAPS = previousValue; // Reset end-caps

    // Calculate the area of all traces within the detector circuit
    this.calculatedDetectorTraceArea(numberOfVerticalTraces, numberOfHorizontalTracePairs);
  }

  protected String generateSVG()
  {
    return "";
  }
  
  /* This function calculates the area of all traces within the detector area */
  protected void calculatedDetectorTraceArea(int numberOfVerticalTraces, int numberOfHorizontalTracePairs)
  {
    float fHorizontalOverlap = (DEFAULT_TRACE_WIDTH * 2);

    dDetectorTraceArea = numberOfVerticalTraces * (DEFAULT_TRACE_WIDTH * DETECTOR_HEIGHT) 
      + (numberOfHorizontalTracePairs * 2) * (DETECTOR_SPACING * DEFAULT_TRACE_WIDTH)
      - (numberOfVerticalTraces * fHorizontalOverlap);

    // Add calculated area to the overall area 
    dTotalCalculatedArea += dDetectorTraceArea;
  }
}

// Create features and add them to an ArrayList for later retrieval
void createFeatures()
{
  /* Naming conventions: Features are named as follows: [Feature Name][Compass Direction][Direction and number of trace, starting at zero] 
   * E.g. 'GNDNorthWestVert0' is the first vertical trace going from the top-left GND pin
   */
  
  // Initialise Array List to store features 
  featuresInDevice = new ArrayList<Feature>();

  /* Features and equations that define their positions */
  
  /* Pin constructor (Center x coordinate, 
  Center y coordinate, 
  Pin diameter, 
  Previous Feature, [label text]) */

  Pin ANorthEast = new Pin(DEVICE_AREA - (PIN_DIAMETER / 2), 
    (PIN_DIAMETER / 2), 
    PIN_DIAMETER, 
    null, "A"); // Set to null now as we haven't yet initialised ANorthWestHorizontal0

  Pin ANorthWest = new Pin(PIN_DIAMETER + PIN_SPACING + (PIN_DIAMETER / 2), 
    PIN_DIAMETER / 2, 
    PIN_DIAMETER, 
    null, "A");

  /* Trace constructor (Start x coordinate,
   start y coordinate,
   width, 
   height, 
   previous feature, trace type) */
  Trace ANorthWestHorizontal0 = new Trace (ANorthWest.fXPosition, 
    ANorthWest.fYPosition, 
    ANorthEast.fXPosition, 
    DEFAULT_TRACE_WIDTH, 
    ANorthWest, "HTRACE");
  ANorthEast.setPreviousFeature(ANorthWestHorizontal0); // Set the previous feature 

  // Trace connecting ANorthWest to the detector
  Trace ANorthWestVertDetector = new Trace((DEVICE_AREA / 2) - (DETECTOR_WIDTH / 2),
    ANorthWest.fYPosition, 
    (DEVICE_AREA / 2) - (DETECTOR_WIDTH / 2), 
    (DEVICE_AREA / 2) - (DETECTOR_HEIGHT / 2), 
    ANorthWestHorizontal0, "VTRACE");

  Pin GNDNorthWest = new Pin(PIN_DIAMETER / 2,
    PIN_SPACING * 2, 
    PIN_DIAMETER, 
    null, "GND");

  Pin GNDSouthWest = new Pin(PIN_DIAMETER / 2,
   DEVICE_AREA - (PIN_DIAMETER / 2), 
   PIN_DIAMETER, 
   null, "GND"); // Set to null for now as we haven't yet initialised GNDNorthWestVert0

  Trace GNDNorthWestVert0 = new Trace(GNDNorthWest.fXPosition,
   GNDNorthWest.fYPosition, 
   GNDSouthWest.fXPosition, 
   GNDSouthWest.fYPosition, 
   GNDNorthWest, "VTRACE");
  GNDSouthWest.setPreviousFeature(GNDNorthWestVert0);
  
  Pin VccNorthWest = new Pin(PIN_DIAMETER / 2,
   PIN_DIAMETER / 2, 
   PIN_DIAMETER, 
   null, "VCC");

  Trace VccNorthWestFortyFive0 = new Trace(VccNorthWest.fXPosition,
   VccNorthWest.fYPosition,
   VccNorthWest.fXPosition + (PIN_DIAMETER / 2) + MINIMUM_FEATURE_SIZE + DEFAULT_TRACE_WIDTH / 2,
   VccNorthWest.fYPosition + (PIN_DIAMETER / 2) + MINIMUM_FEATURE_SIZE + DEFAULT_TRACE_WIDTH / 2,
   VccNorthWest, "45ATRACE");

  Trace VccNorthWestVert0 = new Trace(GNDNorthWest.fXPosition + (PIN_DIAMETER / 2) + MINIMUM_FEATURE_SIZE + (DEFAULT_TRACE_WIDTH / 2),
    VccNorthWestFortyFive0.fHeight, 
    DEFAULT_TRACE_WIDTH, 
    PIN_DIAMETER * 2.5, 
    VccNorthWestFortyFive0, "VTRACE");

  Trace VccNorthWestFortyFive1 = new Trace(VccNorthWestVert0.fXStart - DEFAULT_TRACE_WIDTH*1.5, 
    VccNorthWestVert0.fHeight, 
    VccNorthWestVert0.fXStart,
    VccNorthWestVert0.fHeight + DEFAULT_TRACE_WIDTH*1.5,  
    VccNorthWestVert0, "45BTRACE");

  Trace VccNorthWestVert1 = new Trace(GNDNorthWest.fXPosition + MINIMUM_FEATURE_SIZE + DEFAULT_TRACE_WIDTH,
    VccNorthWestFortyFive1.fHeight,
    GNDNorthWest.fXPosition + MINIMUM_FEATURE_SIZE,
    GNDSouthWest.fYPosition - (PIN_DIAMETER / 2) - DEFAULT_TRACE_WIDTH*1.5,
    VccNorthWestFortyFive1, "VTRACE");

  Trace VccNorthWestFortyFive2 = new Trace(GNDSouthWest.fXPosition + (PIN_DIAMETER / 2),
    GNDSouthWest.fYPosition - (PIN_DIAMETER / 2) - MINIMUM_FEATURE_SIZE - (DEFAULT_TRACE_WIDTH / 2), 
    GNDSouthWest.fXPosition + (PIN_DIAMETER / 2) + MINIMUM_FEATURE_SIZE + (DEFAULT_TRACE_WIDTH / 2), 
    GNDSouthWest.fYPosition - (PIN_DIAMETER / 2), 
    VccNorthWestVert1, "45ATRACE");

  Pin BNorthWest = new Pin(PIN_DIAMETER + PIN_SPACING + (PIN_DIAMETER / 2),
   PIN_SPACING*2, 
   PIN_DIAMETER, 
   null, "B");

  Trace BNorthWestFortyFive0 = new Trace(BNorthWest.fXPosition - PIN_DIAMETER,
    BNorthWest.fYPosition + DEFAULT_TRACE_WIDTH, 
    BNorthWest.fXPosition, 
    BNorthWest.fYPosition + (PIN_DIAMETER) + MINIMUM_FEATURE_SIZE, 
    BNorthWest, "45BTRACE");

  Trace BNorthWestVert0 = new Trace(VccNorthWestVert1.fXEnd + MINIMUM_FEATURE_SIZE,
    VccNorthWestVert1.fYStart + DEFAULT_TRACE_WIDTH*1.5, 
    DEFAULT_TRACE_WIDTH,
    GNDSouthWest.fYPosition - PIN_DIAMETER - MINIMUM_FEATURE_SIZE, 
    BNorthWestFortyFive0, "VTRACE");
    
  Trace BNorthWestFortyFive1 = new Trace(GNDSouthWest.fXPosition + PIN_DIAMETER,
    GNDSouthWest.fYPosition - PIN_DIAMETER - DEFAULT_TRACE_WIDTH, 
    GNDSouthWest.fXPosition + PIN_DIAMETER + MINIMUM_FEATURE_SIZE,
    GNDSouthWest.fYPosition - (PIN_DIAMETER / 2) - MINIMUM_FEATURE_SIZE - DEFAULT_TRACE_WIDTH, 
    BNorthWestVert0, "45ATRACE");

  Pin BSouthEast = new Pin(DEVICE_AREA - (PIN_DIAMETER / 2),
   (DEVICE_AREA - PIN_DIAMETER / 2), 
   PIN_DIAMETER, 
   null, "B"); // Set to null as BNorthWestFortyFive2 hasn't been initialised yet

  Pin GNDSouthEast = new Pin(BSouthEast.fXPosition - PIN_DIAMETER - PIN_SPACING, 
    BSouthEast.fYPosition, 
    PIN_DIAMETER,
    null, "GND"); // Set to null as GNDSouthWestHorizontal0 hasn't been initialised yet
    
  Trace BNorthWestHorizontal0 = new Trace (BNorthWestFortyFive1.fXStart + DEFAULT_TRACE_WIDTH, 
    GNDSouthWest.fYPosition - (MINIMUM_FEATURE_SIZE * 2) - (DEFAULT_TRACE_WIDTH * 2), 
    GNDSouthEast.fXPosition - (PIN_DIAMETER * 3), 
    DEFAULT_TRACE_WIDTH, 
    VccNorthWestFortyFive2, "HTRACE");
    
   Trace GNDSouthWestHorizontal0 = new Trace(GNDSouthWest.fXPosition - (DEFAULT_TRACE_WIDTH / 2),
     GNDSouthWest.fYPosition, 
     GNDSouthEast.fXPosition,
     GNDSouthWest.fYPosition, 
     GNDSouthWest, "HTRACE");
   GNDSouthEast.setPreviousFeature(GNDSouthWestHorizontal0);
    
  Pin ASouthEast = new Pin(BSouthEast.fXPosition, 
    BSouthEast.fYPosition - PIN_DIAMETER - PIN_SPACING, 
    PIN_DIAMETER, 
    null, "A"); // Set to null as ANorthEastVert0 hasn't been initialised yet

  Pin VccSouthEast = new Pin(GNDSouthEast.fXPosition, 
    ASouthEast.fYPosition, 
    PIN_DIAMETER, 
    null, "VCC"); // Set to null as VccNorthWestFortyFive3 hasn't been intialised yet

  Trace BNorthWestFortyFive2 = new Trace(BNorthWestHorizontal0.fXEnd - (DEFAULT_TRACE_WIDTH / 2),
    BNorthWestHorizontal0.fYEnd - DEFAULT_TRACE_WIDTH,
    (DEVICE_AREA / 2) + (DETECTOR_WIDTH / 2) - DEFAULT_TRACE_WIDTH,
    (DEVICE_AREA / 2) + (DETECTOR_WIDTH / 2) - (DEFAULT_TRACE_WIDTH / 2),
    BNorthWestHorizontal0, "45BTRACE");
  BSouthEast.setPreviousFeature(BNorthWestFortyFive2);

  /* This is the horizontal part of the trace which connects the output of the detector to the output pin */
  Trace BNorthWestHorizontal1 = new Trace((DEVICE_AREA / 2) + (DETECTOR_WIDTH / 2) - DEFAULT_TRACE_WIDTH / 2,  
    (DEVICE_AREA / 2) + (DETECTOR_HEIGHT / 2) - (DEFAULT_TRACE_WIDTH / 2),
    ASouthEast.fXPosition - (PIN_DIAMETER / 2) - (PIN_SPACING / 2), 
    (DEVICE_AREA / 2) + (DETECTOR_HEIGHT / 2), 
    BNorthWestFortyFive2, "HTRACE"); 
    
  Trace BNorthWestVert1 = new Trace(BNorthWestHorizontal1.fXEnd,
    BNorthWestHorizontal1.fYStart - DEFAULT_TRACE_WIDTH / 2,
    DEFAULT_TRACE_WIDTH,
    VccSouthEast.fYPosition + (PIN_DIAMETER / 2),
    BNorthWestHorizontal1, "VTRACE"); 

  Trace BSouthEastFortyFive0 = new Trace(BNorthWestVert1.fXEnd + (DEFAULT_TRACE_WIDTH * 4),
    BNorthWestVert1.fYEnd,
    BSouthEast.fXPosition - PIN_DIAMETER / 2 - (DEFAULT_TRACE_WIDTH * 2),
    BSouthEast.fYPosition - DEFAULT_TRACE_WIDTH,
    BNorthWestVert1, "45ATRACE"); 
    
  Trace ANorthEastVert0 = new Trace(ANorthEast.fXPosition,
   ANorthEast.fYPosition - (DEFAULT_TRACE_WIDTH / 2), 
   ANorthEast.fXPosition, 
   ASouthEast.fYPosition, 
   ANorthEast, "VTRACE");
  ASouthEast.setPreviousFeature(ANorthEastVert0);

  Trace VccNorthWestHorizontal0 = new Trace (GNDSouthWest.fXPosition + (PIN_DIAMETER / 2) + (MINIMUM_FEATURE_SIZE * 1.5), 
    GNDSouthWest.fYPosition - MINIMUM_FEATURE_SIZE - DEFAULT_TRACE_WIDTH, 
    GNDSouthEast.fXPosition - (PIN_DIAMETER / 2) - DEFAULT_TRACE_WIDTH * 3.5,
    DEFAULT_TRACE_WIDTH, 
    VccNorthWestFortyFive2, "HTRACE"); 

  Trace VccNorthWestFortyFive3 = new Trace(VccNorthWestHorizontal0.fXEnd - (DEFAULT_TRACE_WIDTH / 2),
   VccNorthWestHorizontal0.fYEnd - DEFAULT_TRACE_WIDTH,
   VccSouthEast.fXPosition,
   VccSouthEast.fYPosition,
   VccNorthWestHorizontal0, "45BTRACE");
  VccSouthEast.setPreviousFeature(VccNorthWestFortyFive3); 

  // Trace connecting BSouthEast to VccSouthEast, termination
  Trace BSouthEastFortyFiveVcc = new Trace(BSouthEast.fXPosition,
  BSouthEast.fYPosition,
  VccSouthEast.fXPosition,
  VccSouthEast.fYPosition,
  BSouthEast, "45ATRACE");

  Detector LinearDetector = new Detector(); 

  /* End of feature definitions */

  /* Connections */

  featuresInDevice.add(LinearDetector);  
  
  /* Pins and traces that will be part of the device regardless of whether chaining or not */
  featuresInDevice.add(VccNorthWest);
  featuresInDevice.add(ANorthEast);  
  featuresInDevice.add(BSouthEast); 
  featuresInDevice.add(GNDSouthWest);

  /* Manage Daisychain connections here */ 
  if (ENABLE_DAISYCHAIN)
  {  
    featuresInDevice.add(VccSouthEast);
    featuresInDevice.add(VccNorthWestFortyFive0);
    featuresInDevice.add(VccNorthWestVert0);
    featuresInDevice.add(VccNorthWestFortyFive1);
    featuresInDevice.add(VccNorthWestVert1);
    featuresInDevice.add(VccNorthWestFortyFive2); 
    featuresInDevice.add(VccNorthWestHorizontal0);
    featuresInDevice.add(VccNorthWestFortyFive3);
    
    featuresInDevice.add(GNDNorthWest);
    featuresInDevice.add(GNDSouthEast);
    featuresInDevice.add(GNDSouthWestHorizontal0);
    featuresInDevice.add(GNDNorthWestVert0);
    
    featuresInDevice.add(ANorthWest);
    featuresInDevice.add(ASouthEast);
    featuresInDevice.add(ANorthWestVertDetector);
    
    featuresInDevice.add(BNorthWest);
    featuresInDevice.add(BNorthWestFortyFive0);
    featuresInDevice.add(BNorthWestVert0);
    featuresInDevice.add(BNorthWestFortyFive1);
    featuresInDevice.add(BNorthWestHorizontal0);
    featuresInDevice.add(BNorthWestHorizontal1);
    featuresInDevice.add(BNorthWestVert1);
    featuresInDevice.add(BNorthWestFortyFive2);
    featuresInDevice.add(BSouthEastFortyFive0);

    featuresInDevice.add(ANorthEastVert0);
    featuresInDevice.add(ANorthWestHorizontal0);

    // Draw the terminating trace
    if (ENABLE_TERMINATION)
    {
      featuresInDevice.add(BSouthEastFortyFiveVcc);
    }
  }

  /* End of Connections */

  /*javax.swing.JOptionPane.showMessageDialog(null, variable); */
  /*javax.swing.JOptionPane.showMessageDialog(null, BNorthWestVert0.fWidth);*/
}

// Setup tasks
void setup()
{
  rectMode(CORNER);
  ellipseMode(CENTER);
  size(1000,1000);
  noLoop();
  noSmooth();
  noStroke();
  fill(DEFAULT_COLOR);
  
  textSize(200);
  textAlign(CENTER, CENTER);
  
  PFont LabelFont;
  LabelFont = loadFont("Font.vlw");
  textFont(LabelFont);
  
  // Intialise all objects that are included in the device
  createFeatures();
}

// Main function, draws all features and outputs them in SVG format for manufacturing
void draw()
{
  // Instantiate decimal format for printing very small values
  DecimalFormat display = new DecimalFormat("#.###################");
  
  // Scale display down by a factor of 10 as we don't have a 10000x10000 resolution screen
  scale(0.1);

  // Add the SVG header to the output file
  sbSVGOutput.append(SVG_HEADER + "\n");
 
  for (int deviceFeature = 0; deviceFeature < featuresInDevice.size(); deviceFeature++)
  {
    // Call the draw method for this particular feature
    featuresInDevice.get(deviceFeature).drawFeature();
    if (featuresInDevice.get(deviceFeature) instanceof Trace)
    {
        Trace theTrace = (Trace) featuresInDevice.get(deviceFeature);
        println(theTrace.sTraceType + ": " + (display.format(theTrace.dFeatureArea / 1000000000000L)) + " m^2"); // Print the calculated area of the feature (m^2)
    }
    
    else if (featuresInDevice.get(deviceFeature) instanceof Pin)
    {
      Pin thePin = (Pin) featuresInDevice.get(deviceFeature); 
      println("PIN " + thePin.sLabelText[0] + ": " + display.format(thePin.dFeatureArea) + " m^2"); // Print the calculated area of the feature
    } 

    // Add generated SVG to output
    sbSVGOutput.append(featuresInDevice.get(deviceFeature).generateSVG() + "\n");
  }

  // Append the footer (closing bracket) to the SVG output
  sbSVGOutput.append(SVG_FOOTER);

  // Output the SVG file
  PrintWriter pw = createWriter(SVG_OUTPUT_DIRECTORY + "GeneratedSVG.svg");
  pw.append(sbSVGOutput);
  pw.close();

  if (HIGHLIGHT_DEVICE_CENTER)
  {
    /* Indicate device centre */
    stroke(255,0,0);
    strokeWeight(40);
    line(DEVICE_CENTER, DEVICE_CENTER, DEVICE_CENTER + 500, DEVICE_CENTER);
    line(DEVICE_CENTER, DEVICE_CENTER - 500, DEVICE_CENTER, DEVICE_CENTER);
    line(DEVICE_CENTER - 500, DEVICE_CENTER, DEVICE_CENTER, DEVICE_CENTER);
    line(DEVICE_CENTER, DEVICE_CENTER, DEVICE_CENTER, DEVICE_CENTER + 500);
    noStroke();
    fill(234,230,0);
    ellipse(DEVICE_CENTER, DEVICE_CENTER, 250, 250);
  }

  // Outputs an image, can be viewed on any screen resolution
  save(SVG_OUTPUT_DIRECTORY + "Generated_Component.png");
  
  // Print area and moment values 
  // 1000000000000L is the constant used to convert between square microns and square meters. L signifies 'liteal long'. TODO: In future this should be refactored as a constant or a function
  println("\nTotal Occupied Area: " + display.format(dTotalCalculatedArea / 1000000000000L ) + " m^2"); // Put through formatter to avoid printing in scientific notation
  println("Total Component Area: " + display.format( ((double) DEVICE_AREA * (double) DEVICE_AREA) / 1000000000000L ) + " m^2");  // Convert to double to prevent rounding error

  println("\nX Moment: " + display.format(dOverallMomentX));
  println("Y Moment: " + display.format(dOverallMomentY));
  println("Z Moment: " + display.format(dOverallMomentZ));

  println("\nOverall Moment: " + (dOverallMomentX + dOverallMomentY + dOverallMomentZ));
  println("Overall Mass (g): " + display.format(dOverallMass));
  
  // Offset from device centre of centre of gravity
  // FIXME: Fix this
  double dOffset = (dOverallMomentX + dOverallMomentY + dOverallMomentZ) / dOverallMass;
  
  println("\nCenter Offset: " + dOffset);

  // Enable this flag if to see the live on-screen display
  if (!ENABLE_INTERACTIVE_MODE)
  {
    exit();
  }
}

// Show a dialog box with the calculated area of the detector if the component is clicked on. TODO: In future this could show the same information the print statements do
void mouseClicked()
{
  javax.swing.JOptionPane.showMessageDialog(null, "Calculated Detector Trace Area: " + (dDetectorTraceArea / 1000000 + " mm^2")); // Output in mm^2 
}

