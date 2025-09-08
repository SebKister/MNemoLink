import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/survey_quality_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:widget_zoom/widget_zoom.dart';
import 'star_rating_widget.dart';

import '../mapsurvey.dart';

class SectionCard extends StatefulWidget {
  final Section section;
  final Function(Section, bool)? onSelectionChanged;

  const SectionCard(this.section, {super.key, this.onSelectionChanged});

  @override
  SectionCardState createState() => SectionCardState();
}

class SectionCardState extends State<SectionCard> {
  late  SvgPicture? picture;
  late  String rawSvg;
  late  MapSurvey map;
  late  SurveyQualityService qualityService;
  static const double displayWidth = 512;
  static const double displayHeight = 512;
  static const double margin = 20;

  @override
  void initState() {
    super.initState();
    qualityService = SurveyQualityService();
    map = MapSurvey.build(widget.section);
    final displayMap = map.buildDisplayMap(displayWidth, displayHeight);
    rawSvg = buildSVG(map, displayMap);
    picture = SvgPicture.string(
      rawSvg,
      width: (Platform.isAndroid || Platform.isIOS) ? 50 : 200,
      height: (Platform.isAndroid || Platform.isIOS) ? 50 : 200,
    );
  }

String generateRandomString(int length) {
  const characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random();
  
  return List.generate(length, (index) => characters[random.nextInt(characters.length)])
      .join();
}

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        leading: _buildLeading(),
      ),
    );
  }

  Widget _buildTitle() {
    final direction = widget.section.direction == SurveyDirection.surveyIn ? "in" : "out";
    final shotCount = widget.section.shots.length - 1;
    return Text("${widget.section.name} - direction: $direction - shots: $shotCount");
  }

  Widget _buildSubtitle() {
    final length = widget.section.getLength().toStringAsFixed(2);
    final depthStart = widget.section.getDepthStart().toStringAsFixed(2);
    final depthMin = widget.section.getDepthMin().toStringAsFixed(2);
    final depthMax = widget.section.getDepthMax().toStringAsFixed(2);
    final depthEnd = widget.section.getDepthEnd().toStringAsFixed(2);
    
    return Text(
      "Length: ${length}m - Depth (start-(min/max)-end): "
      "$depthStart-($depthMin/$depthMax)-${depthEnd}m"
    );
  }

  Widget _buildTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.section.getBrokenFlag()) _buildBrokenIcon(),
        if (widget.section.hasProblematicShots()) ...[
          const SizedBox(width: 6),
          _buildProblematicShotsIcon(),
        ],
        const SizedBox(width: 6),
        _buildSectionInfo(),
      ],
    );
  }

  Widget _buildBrokenIcon() {
    return const Tooltip(
      message: 'Recovered section',
      child: Icon(Icons.fmd_bad, color: Colors.orange),
    );
  }

  Widget _buildProblematicShotsIcon() {
    return const Tooltip(
      message: 'Contains shots with calculated lengths',
      child: Icon(Icons.straighten, color: Colors.red),
    );
  }

  Widget _buildSectionInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(DateFormat('yyyy-MM-dd HH:mm').format(widget.section.dateSurvey)),
        const SizedBox(height: 2),
        StarRatingWidget(
          quality: qualityService.scoreSurveySection(widget.section),
          size: 14.0,
        ),
      ],
    );
  }

  Widget _buildLeading() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSelectionCheckbox(),
        _buildPreviewImage(),
      ],
    );
  }

  Widget _buildSelectionCheckbox() {
    return Checkbox(
      value: widget.section.isSelected,
      onChanged: _handleSelectionChange,
      activeColor: Colors.blue,
    );
  }

  Widget _buildPreviewImage() {
    return WidgetZoom(
      heroAnimationTag: generateRandomString(10),
      zoomWidget: Container(child: picture),
    );
  }

  void _handleSelectionChange(bool? value) {
    if (value != null && widget.onSelectionChanged != null) {
      widget.onSelectionChanged!(widget.section, value);
    }
  }

  double _calculateOptimalGridSpacing(double maxExtent) {
    // Target: no more than 10 grid divisions in the largest direction
    const maxGridDivisions = 10;
    
    // Calculate minimum grid spacing needed
    final minSpacing = maxExtent / maxGridDivisions;
    
    // Define preferred grid spacings (multiples of 5m)
    const preferredSpacings = [5.0, 10.0, 15.0, 20.0, 25.0, 50.0, 100.0, 200.0, 500.0, 1000.0];
    
    // Find the smallest preferred spacing that's >= minSpacing
    for (final spacing in preferredSpacings) {
      if (spacing >= minSpacing) {
        return spacing;
      }
    }
    
    // If extent is very large, calculate a custom spacing
    // Round up to nearest multiple of 5
    final customSpacing = ((minSpacing / 5.0).ceil() * 5.0);
    return customSpacing;
  }

  double _calculateSurveyRotationAngle(MapSurvey realMap) {
    if (realMap.points.length < 2) return 0.0;
    
    // Get first and last points
    final firstPoint = realMap.points.first;
    final lastPoint = realMap.points.last;
    
    // Calculate the angle from first to last point
    final deltaX = lastPoint.x - firstPoint.x;
    final deltaY = lastPoint.y - firstPoint.y;
    
    // Calculate angle in radians (atan2 gives angle from positive X-axis)
    // We want the line to go from left to right, so we rotate to align with X-axis
    final angleRadians = atan2(deltaY, deltaX);
    
    // Return negative angle to rotate the survey to horizontal
    return -angleRadians;
  }
  
  MapSurvey _rotateSurvey(MapSurvey originalMap, double angleRadians) {
    if (originalMap.points.isEmpty) return originalMap;
    
    final rotatedMap = MapSurvey();
    final centerX = originalMap.points.first.x;
    final centerY = originalMap.points.first.y;
    
    for (int i = 0; i < originalMap.points.length; i++) {
      final point = originalMap.points[i];
      
      // Translate to origin
      final translatedX = point.x - centerX;
      final translatedY = point.y - centerY;
      
      // Rotate
      final rotatedX = translatedX * cos(angleRadians) - translatedY * sin(angleRadians);
      final rotatedY = translatedX * sin(angleRadians) + translatedY * cos(angleRadians);
      
      // Translate back
      rotatedMap.points.add(Point3d(
        rotatedX + centerX,
        rotatedY + centerY,
        point.z
      ));
      
      // Copy problematic shot tracking
      if (i < originalMap.isProblematicShot.length) {
        rotatedMap.isProblematicShot.add(originalMap.isProblematicShot[i]);
      }
    }
    
    return rotatedMap;
  }

  void _addDepthProfile(StringBuffer result, MapSurvey realMap, MapSurvey rotatedDisplayMap, 
                       double cropMinX, double cropMaxX, double depthSectionStartY, double depthSectionHeight) {
    if (realMap.points.isEmpty) return;
    
    // Calculate actual depth range from original real map (focused range)
    double minDepth = realMap.points.first.z;
    double maxDepth = realMap.points.first.z;
    for (final point in realMap.points) {
      if (point.z < minDepth) minDepth = point.z;
      if (point.z > maxDepth) maxDepth = point.z;
    }
    
    // Focus on actual range with minimal padding (round to nearest 5m)
    final focusedMinDepth = (minDepth / 5.0).floor() * 5.0;
    final focusedMaxDepth = (maxDepth / 5.0).ceil() * 5.0;
    final depthRange = focusedMaxDepth - focusedMinDepth;
    
    // Create focused depth grid lines every 5m (only for the relevant range)
    for (double depth = focusedMinDepth; depth <= focusedMaxDepth; depth += 5.0) {
      final y = depthSectionStartY + ((depth - focusedMinDepth) / depthRange) * depthSectionHeight;
      
      result.writeln(
        "<line x1=\"$cropMinX\" y1=\"$y\" x2=\"$cropMaxX\" y2=\"$y\" "
        "style=\"stroke:#94A3B8;stroke-width:0.6;stroke-opacity:0.8\" />"
      );
      
      // Add depth labels on the left side (same style as main section)
      result.writeln(
        "<text x=\"${cropMinX + 5}\" y=\"${y - 2}\" "
        "style=\"font-size:10px;fill:#1E3A8A;font-weight:500\">${depth.toInt()}m</text>"
      );
    }
    
    // Plot depth profile points using X coordinates from rotated display map
    for (int i = 0; i < realMap.points.length - 1; i++) {
      final realPoint = realMap.points[i];
      final displayX = rotatedDisplayMap.points[i].x;
      
      // Map depth to Y coordinate in depth section
      final depthY = depthSectionStartY + ((realPoint.z - focusedMinDepth) / depthRange) * depthSectionHeight;
      
      // Draw point (same colors as main section)
      result.write(
        "<circle cx=\"$displayX\" cy=\"$depthY\" "
        "r=\"4\" style=\"fill:none;stroke:${(i == 0) ? "#059669" : "#DC2626"};stroke-width:${(i == 0) ? 3 : 1.5}\" />"
        "<text x=\"${displayX + 5}\" y=\"${depthY + 3}\" style=\"font-size:10px;fill:#1E3A8A;font-weight:500\">${realPoint.z.toStringAsFixed(1)}</text>"
      );
      
      // Draw line to next point if not the last (same color as main section)
      if (i < realMap.points.length - 2) {
        final nextRealPoint = realMap.points[i + 1];
        final nextDisplayX = rotatedDisplayMap.points[i + 1].x;
        final nextDepthY = depthSectionStartY + ((nextRealPoint.z - focusedMinDepth) / depthRange) * depthSectionHeight;
        
        // Check if this shot is problematic (calculated length)
        final isProblematic = i + 1 < realMap.isProblematicShot.length && realMap.isProblematicShot[i + 1];
        final strokeDashArray = isProblematic ? "stroke-dasharray:5,5;" : "";
        
        result.write(
          "<line x1=\"$displayX\" y1=\"$depthY\" x2=\"$nextDisplayX\" y2=\"$nextDepthY\" "
          "style=\"stroke:#1E40AF;stroke-width:2.5;$strokeDashArray\" />"
        );
      }
    }
  }

  void _addNorthArrow(StringBuffer result, double cropMinX, double cropMaxX, double cropMinY, double cropMaxY, [double surveyRotationAngle = 0.0]) {
    // Position in lower right corner of the cropped viewBox with some padding
    final arrowCenterX = cropMaxX - 30;
    final arrowCenterY = cropMaxY - 30;
    
    // North direction in original coordinate system is +Y (upward in SVG)
    // Account for survey rotation: if survey is rotated, north arrow rotates opposite direction
    final northAngleDegrees = -surveyRotationAngle * 180 / pi;
    
    // Create compass-style north arrow with pointed diamond design
    result.writeln(
      "<g id=\"north-arrow\">"
      "<circle cx=\"$arrowCenterX\" cy=\"$arrowCenterY\" r=\"20\" "
      "style=\"fill:white;stroke:#374151;stroke-width:1.5;filter:drop-shadow(1px 1px 2px rgba(0,0,0,0.3))\" />"
      "<g transform=\"rotate($northAngleDegrees $arrowCenterX $arrowCenterY)\">"
      // North-pointing diamond (professional red)
      "<polygon points=\"$arrowCenterX,${arrowCenterY - 16} ${arrowCenterX - 4},${arrowCenterY - 2} $arrowCenterX,${arrowCenterY + 2} ${arrowCenterX + 4},${arrowCenterY - 2}\" "
      "style=\"fill:#DC2626;stroke:#1F2937;stroke-width:1\" />"
      // South-pointing diamond (white/light)
      "<polygon points=\"$arrowCenterX,${arrowCenterY + 16} ${arrowCenterX - 4},${arrowCenterY + 2} $arrowCenterX,${arrowCenterY - 2} ${arrowCenterX + 4},${arrowCenterY + 2}\" "
      "style=\"fill:white;stroke:#1F2937;stroke-width:1\" />"
      // N label on the north-pointing side (rotates with arrow)
      "<text x=\"$arrowCenterX\" y=\"${arrowCenterY - 20}\" text-anchor=\"middle\" "
      "style=\"font-size:10px;fill:#1F2937;font-weight:bold\">N</text>"
      "</g>"
      "</g>"
    );
  }

  void _addGridlines(StringBuffer result, MapSurvey realMap, MapSurvey displayMap, double cropMinX, double cropMaxX, double cropMinY, double cropMaxY) {
    if (realMap.points.isEmpty || displayMap.points.isEmpty) return;
    
    // Get the first point as origin (0,0) for grid system in real coordinates
    final realOriginX = realMap.points[0].x;
    final realOriginY = realMap.points[0].y;
    
    // Calculate the range of real coordinates to determine grid bounds
    double realMinX = realMap.points[0].x;
    double realMaxX = realMap.points[0].x;
    double realMinY = realMap.points[0].y;
    double realMaxY = realMap.points[0].y;
    
    for (final point in realMap.points) {
      if (point.x < realMinX) realMinX = point.x;
      if (point.x > realMaxX) realMaxX = point.x;
      if (point.y < realMinY) realMinY = point.y;
      if (point.y > realMaxY) realMaxY = point.y;
    }
    
    // Get display coordinate bounds for clipping
    double displayMinX = displayMap.points[0].x;
    double displayMaxX = displayMap.points[0].x;
    double displayMinY = displayMap.points[0].y;
    double displayMaxY = displayMap.points[0].y;
    
    for (final point in displayMap.points) {
      if (point.x < displayMinX) displayMinX = point.x;
      if (point.x > displayMaxX) displayMaxX = point.x;
      if (point.y < displayMinY) displayMinY = point.y;
      if (point.y > displayMaxY) displayMaxY = point.y;
    }
    
    // Calculate transformation parameters
    final realXSize = realMaxX - realMinX;
    final realYSize = realMaxY - realMinY;
    final realMaxSize = max(realXSize, realYSize);
    
    // Convert coordinates relative to origin for grid calculation
    final gridMinX = realMinX - realOriginX;
    final gridMaxX = realMaxX - realOriginX;
    final gridMinY = realMinY - realOriginY;
    final gridMaxY = realMaxY - realOriginY;
    
    // Calculate dynamic grid spacing to ensure max 10x10 grid
    final maxExtent = max(gridMaxX - gridMinX, gridMaxY - gridMinY);
    final gridSpacing = _calculateOptimalGridSpacing(maxExtent);
    
    
    // Transform a real coordinate to display coordinate
    Point<double> realToDisplay(double realX, double realY) {
      final dispX = (realX - realMinX - (realMaxX - realMinX) / 2.0) * displayWidth / realMaxSize + displayWidth / 2;
      final dispY = (realY - realMinY - (realMaxY - realMinY) / 2.0) * displayHeight / realMaxSize + displayHeight / 2;
      return Point(dispX, dispY);
    }
    
    // Calculate extended grid bounds to fill entire SVG viewport
    // Convert SVG viewport bounds back to real coordinates for extended grid
    final svgMinX = -margin;
    final svgMaxX = displayWidth + margin;
    final svgMinY = -margin;
    final svgMaxY = displayHeight + margin;
    
    // Convert SVG bounds to real coordinates (inverse transformation)
    Point<double> displayToReal(double dispX, double dispY) {
      final realX = ((dispX - displayWidth / 2) * realMaxSize / displayWidth) + (realMaxX + realMinX) / 2;
      final realY = ((dispY - displayHeight / 2) * realMaxSize / displayHeight) + (realMaxY + realMinY) / 2;
      return Point(realX, realY);
    }
    
    final svgTopLeft = displayToReal(svgMinX, svgMinY);
    final svgBottomRight = displayToReal(svgMaxX, svgMaxY);
    
    // Calculate extended grid bounds relative to origin
    final extendedGridMinX = svgTopLeft.x - realOriginX;
    final extendedGridMaxX = svgBottomRight.x - realOriginX;
    final extendedGridMinY = svgTopLeft.y - realOriginY;
    final extendedGridMaxY = svgBottomRight.y - realOriginY;
    
    // Calculate extended grid line positions
    final extendedStartGridX = (extendedGridMinX / gridSpacing).floor() * gridSpacing;
    final extendedEndGridX = (extendedGridMaxX / gridSpacing).ceil() * gridSpacing;
    final extendedStartGridY = (extendedGridMinY / gridSpacing).floor() * gridSpacing;
    final extendedEndGridY = (extendedGridMaxY / gridSpacing).ceil() * gridSpacing;
    
    // Draw vertical grid lines (clipped to section height)
    for (double gridX = extendedStartGridX; gridX <= extendedEndGridX; gridX += gridSpacing) {
      final realX = realOriginX + gridX;
      final topPoint = realToDisplay(realX, svgTopLeft.y);
      final bottomPoint = realToDisplay(realX, svgBottomRight.y);
      
      // Clip the line to the section bounds
      final clippedTopY = max(topPoint.y, cropMinY);
      final clippedBottomY = min(bottomPoint.y, cropMaxY);
      
      result.writeln(
        "<line x1=\"${topPoint.x}\" y1=\"$clippedTopY\" x2=\"${bottomPoint.x}\" y2=\"$clippedBottomY\" "
        "style=\"stroke:#6B7280;stroke-width:0.8;stroke-dasharray:2,2\" />"
      );
      
      // Add label at bottom edge of section
      final absoluteDistance = (realX - realOriginX).abs();
      result.writeln(
        "<text x=\"${topPoint.x}\" y=\"${cropMaxY - 5}\" text-anchor=\"middle\" "
        "style=\"font-size:10px;fill:#374151;font-weight:500\">${absoluteDistance.toInt()}m</text>"
      );
    }
    
    // Draw horizontal grid lines (full SVG width, clipped to section)
    for (double gridY = extendedStartGridY; gridY <= extendedEndGridY; gridY += gridSpacing) {
      final realY = realOriginY + gridY;
      final leftPoint = realToDisplay(svgTopLeft.x, realY);
      final rightPoint = realToDisplay(svgBottomRight.x, realY);
      
      // Only draw line if it's within the section bounds
      if (leftPoint.y >= cropMinY && leftPoint.y <= cropMaxY) {
        result.writeln(
          "<line x1=\"${leftPoint.x}\" y1=\"${leftPoint.y}\" x2=\"${rightPoint.x}\" y2=\"${rightPoint.y}\" "
          "style=\"stroke:#6B7280;stroke-width:0.8;stroke-dasharray:2,2\" />"
        );
        
        // Add label at right edge of cropped SVG (with padding for visibility)
        final absoluteDistance = (realY - realOriginY).abs();
        result.writeln(
          "<text x=\"${cropMaxX - 25}\" y=\"${leftPoint.y + 3}\" "
          "style=\"font-size:10px;fill:#374151;font-weight:500\">${absoluteDistance.toInt()}m</text>"
        );
      }
    }
  }

  String buildSVG(MapSurvey realMap, MapSurvey displayMap) {
    // Calculate rotation angle to align survey left-to-right
    final rotationAngle = _calculateSurveyRotationAngle(realMap);
    
    // Create rotated version of survey data
    final rotatedRealMap = _rotateSurvey(realMap, rotationAngle);
    final rotatedDisplayMap = rotatedRealMap.buildDisplayMap(displayWidth, displayHeight);
    
    // Calculate actual bounds of the rotated survey
    double minX = rotatedDisplayMap.points.first.x;
    double maxX = rotatedDisplayMap.points.first.x;
    double minY = rotatedDisplayMap.points.first.y;
    double maxY = rotatedDisplayMap.points.first.y;
    
    for (final point in rotatedDisplayMap.points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    
    // Expand bounds to include grid labels and north arrow
    // Bottom labels extend 15px below survey area
    // Right labels extend 25px to the right of survey area  
    // North arrow is 40px from bottom-right corner
    const labelPadding = 30.0; // Extra space for labels
    final cropMinX = minX - labelPadding;
    final cropMaxX = maxX + labelPadding;
    final cropMinY = minY - labelPadding;
    final cropMaxY = maxY + labelPadding;
    
    // Calculate cropped dimensions
    final cropWidth = cropMaxX - cropMinX;
    final cropHeight = cropMaxY - cropMinY;
    
    // Force 3:4 aspect ratio (height:width)
    final targetAspectRatio = 3.0 / 4.0; // height / width = 0.75
    final currentAspectRatio = cropHeight / cropWidth;
    
    double finalCropWidth, finalCropHeight;
    double finalCropMinX, finalCropMinY;
    
    if (currentAspectRatio > targetAspectRatio) {
      // Content is too tall, expand width
      finalCropHeight = cropHeight;
      finalCropWidth = cropHeight / targetAspectRatio;
      finalCropMinY = cropMinY;
      finalCropMinX = cropMinX - (finalCropWidth - cropWidth) / 2;
    } else {
      // Content is too wide, expand height  
      finalCropWidth = cropWidth;
      finalCropHeight = cropWidth * targetAspectRatio;
      finalCropMinX = cropMinX;
      finalCropMinY = cropMinY - (finalCropHeight - cropHeight) / 2;
    }
    
    // Extend height by 25% for depth profile section plus padding
    final sectionPadding = 10.0; // Padding between sections
    final extendedCropHeight = finalCropHeight * 1.25 + sectionPadding;
    
    // Calculate scale factor to ensure max dimension doesn't exceed 800px
    final maxDimension = max(finalCropWidth, extendedCropHeight);
    final scaleFactor = maxDimension > 800 ? 800 / maxDimension : 1.0;
    final finalWidth = (finalCropWidth * scaleFactor).round();
    final finalHeight = (extendedCropHeight * scaleFactor).round();
    
    // Define sections: main map keeps original height, depth profile extends below with padding
    final mainSectionHeight = finalCropHeight;
    final depthSectionHeight = finalCropHeight * 0.25; // 25% of main section height
    final depthSectionStartY = finalCropMinY + mainSectionHeight + sectionPadding;
    
    StringBuffer result = StringBuffer("");
    result.writeln(
        "<svg version=\"1.1\" width=\"$finalWidth\" height=\"$finalHeight\" viewBox=\"$finalCropMinX $finalCropMinY $finalCropWidth $extendedCropHeight\" xmlns=\"http://www.w3.org/2000/svg\">");
    // Main survey area background (plan view) - cream for better contrast
    result.writeln(
        "<rect x=\"$finalCropMinX\" y=\"$finalCropMinY\" "
        "width=\"$finalCropWidth\" height=\"$mainSectionHeight\" "
        "style=\"fill:#F8F8F0;stroke:#2C3E50;stroke-width:1\" />");
    
    // Depth profile area background (light blue for depth association) - opaque
    result.writeln(
        "<rect x=\"$finalCropMinX\" y=\"$depthSectionStartY\" "
        "width=\"$finalCropWidth\" height=\"$depthSectionHeight\" "
        "style=\"fill:#F0F8FF;stroke:#2C3E50;stroke-width:1\" />");

    // Add gridlines for main survey section only (screen-aligned, not rotated)  
    _addGridlines(result, rotatedRealMap, rotatedDisplayMap, finalCropMinX, finalCropMinX + finalCropWidth, finalCropMinY, finalCropMinY + finalCropHeight);

    // Render survey lines - use rotated map data
    for (int i = 0; i < rotatedDisplayMap.points.length-2; i++) {
      final isProblematic = i + 1 < rotatedRealMap.isProblematicShot.length && rotatedRealMap.isProblematicShot[i + 1];
      final strokeDashArray = isProblematic ? "stroke-dasharray:5,5;" : "";
      
      result.write(
        "<line x1=\"${rotatedDisplayMap.points[i].x}\" y1=\"${rotatedDisplayMap.points[i].y}\" "
        "x2=\"${rotatedDisplayMap.points[i+1].x}\" y2=\"${rotatedDisplayMap.points[i+1].y}\" "
        "style=\"fill:none;stroke:#1E40AF;stroke-width:2.5;$strokeDashArray\" />"
      );
    }

    // Render survey points with rotated data
    for (int i = 0; i < rotatedDisplayMap.points.length-1; i++) {
      int adjX = rotatedDisplayMap.points[i].x < finalCropMinX + finalCropWidth * 3/4 ? 5 : -40;
      int adjY = rotatedDisplayMap.points[i].y < finalCropMinY + finalCropHeight * 1/5 ? 13 : -3;
      
      result.write(
          "<circle cx=\"${rotatedDisplayMap.points[i].x}\" cy=\"${rotatedDisplayMap.points[i].y}\" "
          "r=\"4\" style = \"fill:none;stroke:${(i == 0) ? "#059669" : "#DC2626"};"
          "stroke-width:${(i == 0) ? 3 : 1.5}\" />"  
          "<text x=\"${rotatedDisplayMap.points[i].x + adjX}\" y=\"${rotatedDisplayMap.points[i].y + adjY}\" "
          "style=\"font-size:11px;fill:#1F2937;font-weight:600;stroke:white;stroke-width:0.3\">$i</text>");
    }

    // Add north arrow accounting for survey rotation (position in main section only)
    _addNorthArrow(result, finalCropMinX, finalCropMinX + finalCropWidth, finalCropMinY, finalCropMinY + finalCropHeight, rotationAngle);

    // Add depth profile section
    _addDepthProfile(result, realMap, rotatedDisplayMap, finalCropMinX, finalCropMinX + finalCropWidth, depthSectionStartY, depthSectionHeight);

    result.write("</svg>");

    return result.toString();
  }
}
