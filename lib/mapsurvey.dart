import 'dart:math';

import 'models/models.dart';

class Point3d extends Point<double> { 
  final double z; 

  Point3d (super.x, super.y, this.z);

  @override
  String toString() => 'Point3d($x, $y, $z)';
}

class MapSurvey {
  int id = 0;
  List<Point3d> points = [];
  List<bool> isProblematicShot = []; // Track which shots are problematic

  MapSurvey();

  void buildMap(Section section) {
    Point3d start = Point3d(0, 0, section.shots.first.depthIn);
    points.add(start);
    
    // Initialize the problematic shot tracking (starts with false for starting point)
    isProblematicShot.add(false);

    for (int i = 0; i < section.shots.length; i++) {
      final shot = section.shots[i];
      
      // Use calculated length if shot is problematic, otherwise use original length
      final lengthToUse = shot.hasProblematicLength() ? shot.getCalculatedLength() : shot.length;
      
      // Track if this shot is problematic
      isProblematicShot.add(shot.hasProblematicLength());
      
      // Calculate horizontal distance using corrected length
      final depthChange = (shot.depthOut - shot.depthIn).abs();
      double factecr;
      
      if (lengthToUse <= depthChange) {
        // For vertical or near-vertical shots, use minimal horizontal distance
        factecr = 0.1;
      } else {
        factecr = sqrt(pow(lengthToUse, 2) - pow(depthChange, 2));
      }
      
      points.add(Point3d(
          points[i].x +
              factecr * sin(-shot.headingOut / 3600.0 * 2.0 * pi),
          points[i].y +
              factecr * cos(shot.headingOut / 3600.0 * 2.0 * pi), 
          max(shot.depthOut, i < section.shots.length-1 ? section.shots[i+1].depthIn : shot.depthOut)));
    }
  }

  MapSurvey.build(Section s) {
    buildMap(s);
  }

  Point3d getMinPoint() {
    double pointx = 1000000.0;
    double pointy = 1000000.0;

    for (int i = 0; i < points.length; i++) {
      if (points[i].x < pointx) pointx = points[i].x;

      if (points[i].y < pointy) pointy = points[i].y;
    }

    return Point3d(pointx, pointy, 0);
  }

  Point3d getMaxPoint() {
    double pointx = -1000000.0;
    double pointy = -1000000.0;

    for (int i = 0; i < points.length; i++) {
      if (points[i].x > pointx) pointx = points[i].x;

      if (points[i].y > pointy) pointy = points[i].y;
    }

    return Point3d(pointx, pointy, 0);
  }

  MapSurvey buildDisplayMap(double displayWidth, double displayHeight) {
    Point3d minPoint = getMinPoint();
    Point3d maxPoint = getMaxPoint();

    double xSize, ySize, maxSize;

    xSize = maxPoint.x - minPoint.x;
    ySize = maxPoint.y - minPoint.y;

    maxSize = max (xSize, ySize); 

    MapSurvey dMap = MapSurvey();

    for (int i = 0; i < points.length; i++) {
      dMap.points.add(Point3d(
          (points[i].x - minPoint.x - (maxPoint.x - minPoint.x) / 2.0) *
                  displayWidth / maxSize +
                  displayWidth / 2,
          (points[i].y - minPoint.y - (maxPoint.y - minPoint.y) / 2.0) *
                  displayHeight / maxSize +
                  displayHeight / 2, 
            points[i].z
            ));
      
      // Copy problematic shot tracking to display map
      if (i < isProblematicShot.length) {
        dMap.isProblematicShot.add(isProblematicShot[i]);
      }
    }

    return dMap;
  }
}
