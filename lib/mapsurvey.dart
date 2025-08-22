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
  List<Shot> shots = []; // Store reference to original shots

  MapSurvey();

  void buildMap(Section section) {
    // Store reference to shots
    shots = section.shots;

    Point3d start = Point3d(0, 0, section.shots.first.depthIn);
    points.add(start);

    for (int i = 0; i < section.shots.length; i++) {
      double factecr = sqrt(pow(section.shots[i].length, 2) -
          pow((section.shots[i].depthOut - section.shots[i].depthIn), 2));
      points.add(Point3d(
          points[i].x +
              factecr * sin(-section.shots[i].headingOut / 3600.0 * 2.0 * pi),
          points[i].y +
              factecr * cos(section.shots[i].headingOut / 3600.0 * 2.0 * pi), 
          max(section.shots[i].depthOut, i < section.shots.length-1 ? section.shots[i+1].depthIn : section.shots[i].depthOut)));
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

  MapSurvey buildDisplayMap(double displayWidth, double displayHeight, {double padding = 0}) {
    Point3d minPoint = getMinPoint();
    Point3d maxPoint = getMaxPoint();

    double xSize, ySize, maxSize;

    xSize = maxPoint.x - minPoint.x;
    ySize = maxPoint.y - minPoint.y;

    maxSize = max (xSize, ySize); 

    MapSurvey dMap = MapSurvey();
    
    // Preserve shot references in the display map
    dMap.shots = shots;

    // Calculate effective display area accounting for padding
    double effectiveWidth = displayWidth - (padding * 2);
    double effectiveHeight = displayHeight - (padding * 2);

    for (int i = 0; i < points.length; i++) {
      dMap.points.add(Point3d(
          (points[i].x - minPoint.x - (maxPoint.x - minPoint.x) / 2.0) *
                  effectiveWidth / maxSize +
                  displayWidth / 2,
          (points[i].y - minPoint.y - (maxPoint.y - minPoint.y) / 2.0) *
                  effectiveHeight / maxSize +
                  displayHeight / 2, 
            points[i].z
            ));
    }

    return dMap;
  }
}
