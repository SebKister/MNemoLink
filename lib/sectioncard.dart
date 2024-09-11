import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mnemolink/section.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mnemolink/shot.dart';

import 'mapsurvey.dart';

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
  static const double displayWidth = 512;
  static const double displayHeight = 512;
  static const double margin = 4;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    map = MapSurvey.build(widget.section);
    rawSvg = buildSVG(map.buildDisplayMap(displayWidth, displayHeight));
    picture = SvgPicture.string(
      rawSvg,
      width: (Platform.isAndroid || Platform.isIOS) ? 50 : 200,
      height: (Platform.isAndroid || Platform.isIOS) ? 50 : 200,
    );
  }

  void _showOverlay(BuildContext context) {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 250, // Adjust based on the position you want the zoomed image to appear
        top: 150, // Adjust to position correctly near the ListTile
        child: Material(
          color: Colors.transparent,
          child: SvgPicture.string(
            rawSvg, // Reuse the SVG data
            width: displayWidth, // Larger size for the hover effect
            height: displayHeight,
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
            "Length: ${widget.section.getLength().toStringAsFixed(2)}m"
            "Depth (start/min/max/end): "
              "${widget.section.getDepthStart().toStringAsFixed(2)}/"
              "${widget.section.getDepthMin().toStringAsFixed(2)}/"
              "${widget.section.getDepthMax().toStringAsFixed(2)}/"
              "${widget.section.getDepthEnd().toStringAsFixed(2)}m"),
        trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget> [
              if (widget.section.getBrokenFlag()) 
                const Tooltip(
                  message: 'Recovered section', // Hover note
                  child: Icon(
                    Icons.fmd_bad, 
                    color: Colors.orange,
                  ),
                ),
              const SizedBox(width: 6), 
              Text(DateFormat('yyyy-MM-dd').format(widget.section.dateSurvey)),
            ],            
          ),
        leading: MouseRegion(
          onEnter: (_) => _showOverlay(context),
          onExit: (_) => _removeOverlay(),
          child: picture, // Initial smaller picture
        ),
      ),
    );
  }

  String buildSVG(MapSurvey map) {
    StringBuffer result = StringBuffer("");
    result.writeln(
        "<svg version=\"1.1\" height=\"800\" viewBox=\"-$margin -$margin ${displayWidth + margin} ${displayHeight + margin}\" xmlns=\"http://www.w3.org/2000/svg\">");
    result.writeln(
        "<rect x=\"-${margin - 1}\" y=\"-${margin - 1}\" "
        "width=\"${displayWidth + margin - 1}\" height=\"${displayHeight + margin -1 }\" "
        "style=\"fill:lightgrey;fill-opacity:0.6;stroke:blue;stroke-width:0.5;stroke-opacity:1\" />");

    result.write("<polyline points=\"");

    for (int i = 0; i < map.points.length-1; i++) {
      if (i != 0) result.write(" ");
      result.write(map.points[i].x);
      result.write(",");
      result.write(map.points[i].y);
    }
    result.write("\" style = \"fill:none;stroke:black;stroke-width:2\" />");

    for (int i = 0; i < map.points.length-1; i++) {
      int adjX = map.points[i].x < displayWidth * 3/4 ? 5 : -40;   // move text starting point to the left if we're in the right band of SVG
      int adjY = map.points[i].y < displayHeight * 1/5 ? 10 : 0; // lower the textpath if we're in the upper part of the SVG
      
      result.write(
          "<circle cx=\"${map.points[i].x}\" cy=\"${map.points[i].y}\" "
          "r=\"4\" style = \"fill:none;stroke:${(i == 0) ? "yellow" : "red"};"
          "stroke-width:${(i == 0) ? 3 : 0.5}\" />"  
          "<text x=\"${map.points[i].x + adjX}\" y=\"${map.points[i].y + adjY}\">${map.points[i].z.toStringAsFixed(2)}</text>");
    }

    result.write("</svg>");

    return result.toString();
  }
}
