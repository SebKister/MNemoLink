import 'enums.dart';

/// Represents a single shot measurement in a cave survey
class Shot {
  // Core measurement data
  TypeShot typeShot;
  double length;
  double depthIn;
  double depthOut;
  
  // Compass readings (in degrees * 10)
  int headingIn;
  int headingOut;
  int pitchIn;
  int pitchOut;
  
  // LRUD measurements (Left, Right, Up, Down)
  double left;
  double right;
  double up;
  double down;
  
  // Additional metadata
  int temperature;
  int hr;  // Hour
  int min; // Minute  
  int sec; // Second
  int markerIndex;

  /// Default constructor
  Shot({
    this.typeShot = TypeShot.std,
    this.length = 0.0,
    this.headingIn = 0,
    this.headingOut = 0,
    this.pitchIn = 0,
    this.pitchOut = 0,
    this.depthIn = 0.0,
    this.depthOut = 0.0,
    this.left = 0.0,
    this.right = 0.0,
    this.up = 0.0,
    this.down = 0.0,
    this.temperature = 0,
    this.hr = 0,
    this.min = 0,
    this.sec = 0,
    this.markerIndex = 0,
  });

  /// Creates a zero-valued shot
  Shot.zero() : this();

  // Legacy getters/setters for compatibility with existing code
  TypeShot getTypeShot() => typeShot;
  void setTypeShot(TypeShot newTypeShot) => typeShot = newTypeShot;
  
  double getLength() => length;
  void setLength(double newLength) => length = newLength;
  
  double getDepthIn() => depthIn;
  void setDepthIn(double newDepthIn) => depthIn = newDepthIn;
  
  double getDepthOut() => depthOut;
  void setDepthOut(double newDepthOut) => depthOut = newDepthOut;
  
  int getHeadingIn() => headingIn;
  void setHeadingIn(int newHeadingIn) => headingIn = newHeadingIn;
  
  int getHeadingOut() => headingOut;
  void setHeadingOut(int newHeadingOut) => headingOut = newHeadingOut;
  
  int getPitchIn() => pitchIn;
  void setPitchIn(int newPitchIn) => pitchIn = newPitchIn;
  
  int getPitchOut() => pitchOut;
  void setPitchOut(int newPitchOut) => pitchOut = newPitchOut;
  
  double getLeft() => left;
  void setLeft(double newLeft) => left = newLeft;
  
  double getRight() => right;
  void setRight(double newRight) => right = newRight;
  
  double getUp() => up;
  void setUp(double newUp) => up = newUp;
  
  double getDown() => down;
  void setDown(double newDown) => down = newDown;
  
  int getTemperature() => temperature;
  void setTemperature(int newTemperature) => temperature = newTemperature;
  
  int getHr() => hr;
  void setHr(int newHr) => hr = newHr;
  
  int getMin() => min;
  void setMin(int newMin) => min = newMin;
  
  int getSec() => sec;
  void setSec(int newSec) => sec = newSec;
  
  int getMarkerIndex() => markerIndex;
  void setMarkerIndex(int newMarkerIndex) => markerIndex = newMarkerIndex;
}