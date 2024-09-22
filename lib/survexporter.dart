import 'package:mnemolink/section.dart';
import 'package:mnemolink/shot.dart';
import 'package:mnemolink/shotexport.dart';

class SurvexExporter with ShotExport {
  @override
  String get extension => '.svx';

  Future<String> headerComments() async {
    final String version = await getAppVersion();

    String header = '''
; svx file initially created:
; * with MNemolink version $version
; * at ${DateTime.now().toIso8601String()}

''';

    return header;
  }

  @override
  Future<String> getContents(Section section, ExportShots exportShots,
      String surveyName, UnitType unitType) async {
    StringBuffer contents = StringBuffer(await headerComments());
    StringBuffer lurdContents = StringBuffer();

    contents.write(newLine('*begin $surveyName'));

    increasePrefix();
    contents.write(newLine('; First and last stations automatically exported'));

    // Exporting first and last stations
    final int lastStation = exportShots.shots.length + 1;
    final String export = "1 ${lastStation.toString()}";
    contents.write(newLine('*export $export'));
    contents.write('\n');

    contents.write(newLine('*title "$surveyName"'));
    contents.write('\n');

    contents.write(newLine('*date ${dateInExportFormat(section.dateSurvey)}'));
    contents.write('\n');

    // Additional contents based on data
    contents.write(newLine(
        '; Uncomment and fill the lines below to set the team members names.'));
    contents.write(newLine(';*team "" explorer'));
    contents.write(newLine(';*team "" surveyor'));
    contents.write('\n');

    contents.write(newLine('*require 1.2.21'));
    contents.write('\n');

    contents.write(newLine('*instrument compass "MNemo V2"'));
    contents.write(newLine('*instrument depth "MNemo V2"'));
    contents.write(newLine('*instrument tape "MNemo V2"'));
    contents.write('\n');

    contents.write(newLine('*sd compass 1.5 degrees'));
    contents.write(newLine('*sd depth 0.1 metres'));
    contents.write(newLine('*sd tape 0.086 metres'));
    contents.write('\n');

    contents.write(newLine('*calibrate depth 0 -1'));
    contents.write('\n');

    // Unit handling
    if (unitType == UnitType.metric) {
      contents.write(newLine('*units tape depth metres'));
    } else {
      contents.write(newLine('*units tape depth feet'));
    }
    contents.write('\n');

    // Main topo data
    contents.write(newLine(
        '*data diving from to tape compass backcompass fromdepth todepth ignoreall'));
    contents.write(newLine(
        '; From\tTo\tLength\tAzIn\t180-AzOut\tDepIn\tDepOut\tAzIn\tAzOut\tAzDelta\tPitchIn\tPitchOut'));
    contents.write('\n');

    bool firstLine = true;
    for (ExportShot exportShot in exportShots.shots) {
      if (exportShot.azimuthComments.isNotEmpty) {
        if (!firstLine) {
          contents.write('\n');
        }

        for (var comment in exportShot.azimuthComments) {
          contents.write(newLine('; $comment'));
        }
      }

      // Formatting the measurement line
      contents.write(newLine(
          '${exportShot.from}\t${exportShot.to}\t${exportShot.length.toStringAsFixed(2)}\t${exportShot.azimuthIn.toStringAsFixed(1)}\t${exportShot.azimuthOut180.toStringAsFixed(1)}\t${exportShot.depthIn.toStringAsFixed(2)}\t${exportShot.depthOut.toStringAsFixed(2)}\t${exportShot.azimuthMean.toStringAsFixed(1)}\t${exportShot.azimuthOut.toStringAsFixed(1)}\t${exportShot.azimuthDelta.toStringAsFixed(1)}\t${exportShot.pitchIn.toStringAsFixed(1)}\t${exportShot.pitchOut.toStringAsFixed(1)}'));

      if (exportShot.lurdShots.isNotEmpty) {
        lurdContents.write(newLine('; LURD for station ${exportShot.to}'));
        for (LURDShot lurdShot in exportShot.lurdShots) {
          lurdContents.write(newLine(
              '; ${enumToStringWithoutClassName(lurdShot.direction.toString())}'));
          lurdContents.write(newLine(
              '${exportShot.to}\t-\t${lurdShot.length.toStringAsFixed(2)}\t${lurdShot.azimuth.toStringAsFixed(1)}\t${lurdShot.clino.toStringAsFixed(1)}'));
        }
        lurdContents.write('\n');
      }

      firstLine = false;
    }
    contents.write('\n');

    if (lurdContents.isNotEmpty) {
      contents.write(newLine('; LURD measurements'));
      contents.write(newLine('*data normal from to tape compass clino'));
      contents.write('\n');
      contents.write(lurdContents.toString());
    }

    // Finalizing the survey contents
    decreasePrefix();
    contents.write(newLine('*end $surveyName'));

    return contents.toString();
  }
}
