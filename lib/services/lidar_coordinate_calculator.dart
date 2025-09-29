import 'dart:math';
import '../mapsurvey.dart';
import '../models/models.dart';

/// Utility class for calculating Lidar global coordinates on-demand
class LidarCoordinateCalculator {
  /// Calculate global coordinates for a Lidar point given shot position
  static Point3d calculateGlobalCoordinates(
    LidarPoint point,
    double shotX,
    double shotY,
    double shotZ,
  ) {
    // Convert angles to radians
    final yawRadians = point.yaw * pi / 180.0;
    final pitchRadians = point.pitch * pi / 180.0;
    final distanceMeters = point.distance; 

    // Calculate global coordinates relative to shot position
    // X: East-West (positive = East) - sin(yaw) where yaw=0 is north
    // Y: North-South (positive = North) - cos(yaw) where yaw=0 is north
    // Z: Vertical (positive = up)
    final globalX = shotX + distanceMeters * cos(pitchRadians) * sin(yawRadians);
    final globalY = shotY + distanceMeters * cos(pitchRadians) * cos(yawRadians);
    final globalZ = shotZ + distanceMeters * sin(pitchRadians);

    return Point3d(globalX, globalY, globalZ);
  }

  /// Calculate shot positions for a section (replicates MapSurvey.buildMap logic)
  static List<Point3d> calculateShotPositions(Section section) {
    final points = <Point3d>[];
    final start = Point3d(0, 0, section.shots.first.depthIn);
    points.add(start);

    for (int i = 0; i < section.shots.length; i++) {
      final shot = section.shots[i];

      // Use calculated length if shot is problematic, otherwise use original length
      final lengthToUse = shot.hasProblematicLength() ? shot.getCalculatedLength() : shot.length;

      // Calculate horizontal distance using corrected length
      final depthChange = shot.depthOut - shot.depthIn; // Preserve sign for direction
      final absDepthChange = depthChange.abs();
      double horizontalDistance;

      if (lengthToUse <= absDepthChange) {
        // For vertical or near-vertical shots, use minimal horizontal distance
        horizontalDistance = 0.1;
      } else {
        horizontalDistance = sqrt(pow(lengthToUse, 2) - pow(absDepthChange, 2));
      }

      // Get the best vertical displacement (depth sensor or calculated from angles)
      final verticalDisplacement = shot.getBestVerticalDisplacement();

      points.add(Point3d(
        points[i].x + horizontalDistance * sin(-shot.headingOut * pi / 180.0),
        points[i].y + horizontalDistance * cos(shot.headingOut * pi / 180.0),
        points[i].z + verticalDisplacement // Use calculated vertical displacement
      ));
    }

    return points;
  }

  /// Get all Lidar points with global coordinates for a section
  static List<Point3d> getAllLidarGlobalPoints(Section section) {
    final shotPositions = calculateShotPositions(section);
    final allLidarPoints = <Point3d>[];

    for (int shotIndex = 0; shotIndex < section.shots.length - 1; shotIndex++) {
      final shot = section.shots[shotIndex];
      if (!shot.hasLidarData() || shotIndex + 1 >= shotPositions.length) continue;

      final lidarData = shot.lidarData!;
      // Lidar measurements are taken at the arriving point (end) of the shot
      final shotPosition = shotPositions[shotIndex + 1];

      for (final lidarPoint in lidarData.points) {
        final globalPoint = calculateGlobalCoordinates(
          lidarPoint,
          shotPosition.x,
          shotPosition.y,
          shotPosition.z,
        );
        allLidarPoints.add(globalPoint);
      }
    }

    return allLidarPoints;
  }
}