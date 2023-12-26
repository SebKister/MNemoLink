import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mnemolink/section.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mnemolink/shot.dart';

import 'mapsurvey.dart';

class SectionCard extends StatelessWidget {
  final Section section;
  late final SvgPicture? picture;
  late final String rawSvg;
  late final MapSurvey map;
  static const double displayWidth = 256;
  static const double displayHeight = 256;
  static const double margin = 4;

  SectionCard(this.section, {super.key}) {
    map = MapSurvey.build(section);
    rawSvg = buildSVG(map.buildDisplayMap(displayWidth, displayHeight));
    picture = SvgPicture.string(
      rawSvg,
      width: 200,
      height: 200,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(section.name),
        subtitle: Text(
            "${(section.direction == SurveyDirection.surveyIn) ? "IN" : "OUT"}-#${section.shots.length - 1}"),
        trailing: Text(DateFormat('yyyy-MM-dd').format(section.dateSurvey)),
        leading: picture,
      ),
    );
  }

  String buildSVG(MapSurvey map) {
    StringBuffer result = StringBuffer("");
    result.writeln(
        "<svg version=\"1.1\" height=\"800\" viewBox=\"-$margin -$margin ${displayWidth + margin} ${displayHeight + margin}\" xmlns=\"http://www.w3.org/2000/svg\">");
    result.writeln(
        "<rect x=\"-${margin / 2}\" y=\"-${margin / 2}\" width=\"${displayWidth + margin / 2}\" height=\"${displayHeight + margin / 2}\" style=\"fill:black;stroke:blue;stroke-width:0.5;fill-opacity:0.1;stroke-opacity:1\" />");

    result.write("<polyline points=\"");

    for (int i = 0; i < map.points.length; i++) {
      if (i != 0) result.write(" ");
      result.write(map.points[i].x);
      result.write(",");
      result.write(map.points[i].y);
    }
    result.write("\" style = \"fill:none;stroke:black;stroke-width:2\" />");

    for (int i = 0; i < map.points.length; i++) {
      result.write(
          "<circle cx=\"${map.points[i].x}\" cy=\"${map.points[i].y}\" r=\"3\" style = \"fill:none;stroke:${(i == 0) ? "yellow" : "red"};stroke-width:0.5\" />");
    }
    result.write("</svg>");

    return result.toString();
  }
}
