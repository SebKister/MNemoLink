/// Represents a single Lidar measurement point
class LidarPoint {
  final double yaw;       // degrees (processed measurement)
  final double pitch;     // degrees (processed measurement)
  final double distance;  // m (processed measurement)

  const LidarPoint({
    required this.yaw,
    required this.pitch,
    required this.distance,
  });

  /// Get yaw in degrees (for compatibility)
  double get yawDegrees => yaw;

  /// Get pitch in degrees (for compatibility)
  double get pitchDegrees => pitch;
}

/// Represents Lidar data collection for a shot
class LidarData {
  final List<LidarPoint> points;

  const LidarData({required this.points});

  /// Check if this contains valid Lidar data
  bool get hasData => points.isNotEmpty;

  /// Get number of Lidar points
  int get pointCount => points.length;
}