import 'dart:math';
import 'enums.dart';
import 'lidar_data.dart';

/// Represents a single shot measurement in a cave survey
class Shot {
  // Core measurement data
  TypeShot typeShot;
  double length;
  double depthIn;
  double depthOut;
  
  // Compass readings (in degrees)
  double headingIn;
  double headingOut;
  double pitchIn;
  double pitchOut;
  
  // LRUD measurements (Left, Right, Up, Down)
  double left;
  double right;
  double up;
  double down;
  
  // Additional metadata
  double temperature;
  int hr;  // Hour
  int min; // Minute
  int sec; // Second
  int markerIndex;

  // Optional Lidar data (V6 format and later)
  LidarData? lidarData;

  /// Default constructor
  Shot({
    this.typeShot = TypeShot.std,
    this.length = 0.0,
    this.headingIn = 0.0,
    this.headingOut = 0.0,
    this.pitchIn = 0.0,
    this.pitchOut = 0.0,
    this.depthIn = 0.0,
    this.depthOut = 0.0,
    this.left = 0.0,
    this.right = 0.0,
    this.up = 0.0,
    this.down = 0.0,
    this.temperature = 0.0,
    this.hr = 0,
    this.min = 0,
    this.sec = 0,
    this.markerIndex = 0,
    this.lidarData,
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
  
  double getHeadingIn() => headingIn;
  void setHeadingIn(double newHeadingIn) => headingIn = newHeadingIn;

  double getHeadingOut() => headingOut;
  void setHeadingOut(double newHeadingOut) => headingOut = newHeadingOut;

  double getPitchIn() => pitchIn;
  void setPitchIn(double newPitchIn) => pitchIn = newPitchIn;

  double getPitchOut() => pitchOut;
  void setPitchOut(double newPitchOut) => pitchOut = newPitchOut;
  
  double getLeft() => left;
  void setLeft(double newLeft) => left = newLeft;
  
  double getRight() => right;
  void setRight(double newRight) => right = newRight;
  
  double getUp() => up;
  void setUp(double newUp) => up = newUp;
  
  double getDown() => down;
  void setDown(double newDown) => down = newDown;
  
  double getTemperature() => temperature;
  void setTemperature(double newTemperature) => temperature = newTemperature;
  
  int getHr() => hr;
  void setHr(int newHr) => hr = newHr;
  
  int getMin() => min;
  void setMin(int newMin) => min = newMin;
  
  int getSec() => sec;
  void setSec(int newSec) => sec = newSec;
  
  int getMarkerIndex() => markerIndex;
  void setMarkerIndex(int newMarkerIndex) => markerIndex = newMarkerIndex;
  
  /// Get the depth change for this shot
  double getDepthChange() => (depthOut - depthIn).abs();
  
  /// Check if this shot has problematic length (length < depth change)
  bool hasProblematicLength() {
    final depthChange = getDepthChange();
    return length > 0 && length < depthChange;
  }
  
  /// Calculate corrected length based on inclination and depth change
  double getCalculatedLength() {
    if (!hasProblematicLength()) return length;
    
    final depthChange = getDepthChange();
    // Use average inclination from pitchIn and pitchOut (already in degrees)
    final avgPitch = (pitchIn + pitchOut) / 2.0;
    final radians = avgPitch * pi / 180.0; // Convert to radians
    
    // If inclination is near 90 degrees (vertical), use depth change as length
    if (cos(radians).abs() < 0.1) {
      return depthChange;
    }
    
    // Calculate length using trigonometry: length = depth_change / sin(inclination)
    return depthChange / sin(radians).abs();
  }
  
  /// Check if this shot uses calculated length (for display purposes)
  bool usesCalculatedLength() => hasProblematicLength();

  /// Calculate true vertical displacement using pitch angles
  /// This is used when depth sensor is unreliable (e.g., above water scenarios)
  double getCalculatedVerticalDisplacement() {
    final lengthToUse = hasProblematicLength() ? getCalculatedLength() : length;
    final avgPitch = (pitchIn + pitchOut) / 2.0;
    final pitchRadians = avgPitch * pi / 180.0;

    return lengthToUse * sin(pitchRadians);
  }

  /// Get the best available vertical displacement
  /// Uses depth sensor data when reliable, otherwise calculates from angles
  double getBestVerticalDisplacement() {
    final depthChange = depthOut - depthIn; // Preserve sign
    final absDepthChange = depthChange.abs();
    final lengthToUse = hasProblematicLength() ? getCalculatedLength() : length;

    // If depth sensor reading is very small but we have significant length and pitch,
    // prefer calculated displacement from angles
    if (absDepthChange < 0.1 && lengthToUse > 0.5) {
      return getCalculatedVerticalDisplacement();
    } else {
      // Use depth sensor reading
      return depthChange;
    }
  }

  /// Check if this shot has Lidar data
  bool hasLidarData() => lidarData?.hasData ?? false;
}