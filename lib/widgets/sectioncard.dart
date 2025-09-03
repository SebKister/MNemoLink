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

  const SectionCard(this.section, {super.key});

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
    rawSvg = buildSVG(map.buildDisplayMap(displayWidth, displayHeight));
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
        title: Text(
          "${widget.section.name} - "
          "dir: ${(widget.section.direction == SurveyDirection.surveyIn) ? "in" : "out"} - "
          "shots: ${widget.section.shots.length - 1}"),
        subtitle: Text(
            "Length: ${widget.section.getLength().toStringAsFixed(2)}m - "
            "Depth (start-(min/max)-end): "
              "${widget.section.getDepthStart().toStringAsFixed(2)}-"
              "(${widget.section.getDepthMin().toStringAsFixed(2)}/"
              "${widget.section.getDepthMax().toStringAsFixed(2)})-"
              "${widget.section.getDepthEnd().toStringAsFixed(2)}m"),
        trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget> [
              if (widget.section.getBrokenFlag()) 
                const Tooltip(
                  message: 'Recovered section', 
                  child: Icon(
                    Icons.fmd_bad, 
                    color: Colors.orange,
                  ),
                ),
              if (widget.section.hasProblematicShots()) ...[
                const SizedBox(width: 6),
                const Tooltip(
                  message: 'Contains shots with calculated lengths',
                  child: Icon(
                    Icons.straighten,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(width: 6), 
              Column(
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
              ),
            ],            
          ),
        leading: WidgetZoom(
            heroAnimationTag: generateRandomString(10),
            zoomWidget: Container( 
                child: picture,
            ),
        ),
      ),
    );
  }

  String buildSVG(MapSurvey map) {
    StringBuffer result = StringBuffer("");
    result.writeln(
        "<svg version=\"1.1\" height=\"800\" viewBox=\"-$margin -$margin ${displayWidth + 2 * margin} ${displayHeight + 2 * margin}\" xmlns=\"http://www.w3.org/2000/svg\">");
    result.writeln(
        "<rect x=\"-${margin - 1}\" y=\"-${margin - 1}\" "
        "width=\"${displayWidth + 2 * margin - 1}\" height=\"${displayHeight + 2 * margin - 1}\" "
        "style=\"fill:lightgrey;fill-opacity:0.6;stroke:blue;stroke-width:0.5;stroke-opacity:1\" />");

    // Render survey lines - use individual line segments to handle dashing
    for (int i = 0; i < map.points.length-2; i++) {
      final isProblematic = i + 1 < map.isProblematicShot.length && map.isProblematicShot[i + 1];
      final strokeDashArray = isProblematic ? "stroke-dasharray:5,5;" : "";
      
      result.write(
        "<line x1=\"${map.points[i].x}\" y1=\"${map.points[i].y}\" "
        "x2=\"${map.points[i+1].x}\" y2=\"${map.points[i+1].y}\" "
        "style=\"fill:none;stroke:black;stroke-width:2;$strokeDashArray\" />"
      );
    }

    for (int i = 0; i < map.points.length-1; i++) {
      int adjX = map.points[i].x < displayWidth * 3/4 ? 5 : -40;   // move text starting point to the left if we're in the right band of SVG
      int adjY = map.points[i].y < displayHeight * 1/5 ? 13 : -3;   // lower the textpath if we're in the upper part of the SVG
      
      result.write(
          "<circle cx=\"${map.points[i].x}\" cy=\"${map.points[i].y}\" "
          "r=\"4\" style = \"fill:none;stroke:${(i == 0) ? "yellow" : "red"};"
          "stroke-width:${(i == 0) ? 3 : 0.5}\" />"  
          "<text x=\"${map.points[i].x + adjX}\" y=\"${map.points[i].y + adjY}\">${map.points[i].z.toStringAsFixed(1)}</text>");
    }

    result.write("</svg>");

    return result.toString();
  }
}
