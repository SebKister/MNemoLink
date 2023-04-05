import 'dart:math';

import 'package:mnemolink/section.dart';

class MapSurvey {
  int ID = 0;
  List<Point<double>> points = [];

  MapSurvey() {}

  void buildMap(Section section) {
// Get the empty section case out of the way
    if (section.shots.length < 2) return;

    Point<double> start = const Point<double>(0, 0);
    points.add(start);

    for (int i = 0; i < section.shots.length; i++) {
      double factecr = sqrt(pow(section.shots[i].length, 2) -
          pow((section.shots[i].depthOut - section.shots[i].depthIn), 2));
      points.add(Point(
          points[i].x +
              factecr * sin(-section.shots[i].headingOut / 3600.0 * 2.0 * pi),
          points[i].y +
              factecr * cos(section.shots[i].headingOut / 3600.0 * 2.0 * pi)));
    }
  }

  MapSurvey.build(Section s) {
    buildMap(s);
  }

  Point<double> getMinPoint() {
    double pointx = 1000000.0;
    double pointy = 1000000.0;

    for (int i = 0; i < points.length; i++) {
      if (points[i].x < pointx) pointx = points[i].x;

      if (points[i].y < pointy) pointy = points[i].y;
    }

    return Point<double>(pointx, pointy);
  }

  Point<double> getMaxPoint() {
    double pointx = -1000000.0;
    double pointy = -1000000.0;

    for (int i = 0; i < points.length; i++) {
      if (points[i].x > pointx) pointx = points[i].x;

      if (points[i].y > pointy) pointy = points[i].y;
    }

    return Point<double>(pointx, pointy);
  }

  MapSurvey buildDisplayMap(double displayWidth, double displayHeight) {
    Point<double> minPoint = getMinPoint();
    Point<double> maxPoint = getMaxPoint();

    double xSize, ySize, maxSize;

    xSize = maxPoint.x - minPoint.x;
    ySize = maxPoint.y - minPoint.y;

    if (xSize > ySize) {
      maxSize = xSize;
    } else {
      maxSize = ySize;
    }

    MapSurvey dMap = MapSurvey();
    double MAPDISPLAYSIZE = displayWidth,
        MAPDISPLAYSIZEX = 3,
        MAPDISPLAYSIZEY = 3;

    for (int i = 0; i < points.length; i++) {
      dMap.points.add(Point(
          (points[i].x - minPoint.x - (maxPoint.x - minPoint.x) / 2.0) *
                  MAPDISPLAYSIZE /
                  maxSize +
              MAPDISPLAYSIZEX +
              MAPDISPLAYSIZE / 2,
          (points[i].y - minPoint.y - (maxPoint.y - minPoint.y) / 2.0) *
                  MAPDISPLAYSIZE /
                  maxSize +
              MAPDISPLAYSIZEY +
              MAPDISPLAYSIZE / 2));
    }

    return dMap;
  }
}
