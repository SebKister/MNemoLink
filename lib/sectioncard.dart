import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mnemolink/section.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'mapsurvey.dart';

class SectionCard extends StatelessWidget {
  final Section section;
  SvgPicture? picture;
  String rawSvg =
      r'<svg width="400" height="110"><rect width="300" height="100" style="fill:rgb(0,0,255);stroke-width:3;stroke:rgb(0,0,0)" /></svg>';
  MapSurvey map=MapSurvey();

  SectionCard(this.section) {
    map=MapSurvey.build(section);
    rawSvg = buildSVG(map.buildDisplayMap());
    picture = SvgPicture.string(rawSvg);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(section.name),
        subtitle: Text("#${section.shots.length}"),
        trailing: Text(DateFormat('yyyy-MM-dd').format(section.dateSurey)),
        leading: picture,
      ),
    );
  }

  String buildSVG(MapSurvey map) {
    StringBuffer result = StringBuffer("");
    StringBuffer bufr = StringBuffer("");
    result.writeln(
        "<svg version=\"1.1\" height=\"800\" viewBox=\"-4 -4 136 136\" xmlns=\"http://www.w3.org/2000/svg\">");
    result.writeln(
        "<rect x=\"-2\" y=\"-2\" width=\"132\" height=\"132\" style=\"fill:black;stroke:blue;stroke-width:0.5;fill-opacity:0.1;stroke-opacity:1\" />");

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
