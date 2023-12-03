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

    String prefix = '';
    contents.write(newLine('*begin $surveyName', prefix));

    prefix = '\t';
    contents.write(
        newLine('; First and last stations automatically exported', prefix));

    // Exporting first and last stations
    final int lastStation = exportShots.shots.length + 1;
    final String export = "1 ${lastStation.toString()}";
    contents.write(newLine('*export $export', prefix));
    contents.write('\n');

    contents.write(newLine('*title "$surveyName"', prefix));
    contents.write('\n');

    contents.write(
        newLine('*date ${dateInExportFormat(section.dateSurvey)}', prefix));
    contents.write('\n');

    // Additional contents based on data
    contents.write(newLine(
        '; Uncomment and fill the lines below to set the team members names.',
        prefix));
    contents.write(newLine(';*team "" explorer', prefix));
    contents.write(newLine(';*team "" surveyor', prefix));
    contents.write('\n');

    contents.write(newLine('*require 1.2.21', prefix));
    contents.write('\n');

    contents.write(newLine('*instrument compass MNemo', prefix));
    contents.write(newLine('*instrument depth MNemo', prefix));
    contents.write(newLine('*instrument tape MNemo', prefix));
    contents.write('\n');

    contents.write(newLine('*sd compass 1.5 degrees', prefix));
    contents.write(newLine('*sd depth 0.1 metres', prefix));
    contents.write(newLine('*sd tape 0.086 metres', prefix));
    contents.write('\n');

    contents.write(newLine('*calibrate depth 0 -1', prefix));
    contents.write('\n');

    // Unit handling
    if (unitType == UnitType.METRIC) {
      contents.write(newLine('*units tape depth metres', prefix));
    } else {
      contents.write(newLine('*units tape depth feet', prefix));
    }
    contents.write('\n');

    // Main topo data
    contents.write(newLine(
        '*data diving from to tape compass fromdepth todepth ignoreall',
        prefix));
    contents.write(newLine(
        '; From\tTo\tLength\tAzimuth\tDepIn\tDepOut\tAzIn\tAzOut\tAzDelta\tPitchIn\tPitchOut',
        prefix));
    contents.write('\n');

    bool firstLine = true;
    for (ExportShot exportShot in exportShots.shots) {
      if (exportShot.azimuthComments.isNotEmpty) {
        if (!firstLine) {
          contents.write('\n');
        }

        for (var comment in exportShot.azimuthComments) {
          contents.write(newLine('; $comment', prefix));
        }
      }

      // Formatting the measurement line
      contents.write(newLine(
          '${exportShot.from}\t${exportShot.to}\t${exportShot.length.toStringAsFixed(2)}\t${exportShot.azimuthMean.toStringAsFixed(1)}\t${exportShot.depthIn.toStringAsFixed(2)}\t${exportShot.depthOut.toStringAsFixed(2)}\t${exportShot.azimuthIn.toStringAsFixed(1)}\t${exportShot.azimuthOut.toStringAsFixed(1)}\t${exportShot.azimuthDelta.toStringAsFixed(1)}\t${exportShot.pitchIn.toStringAsFixed(1)}\t${exportShot.pitchOut.toStringAsFixed(1)}',
          prefix));
      firstLine = false;
    }
    contents.write('\n');

    // Finalizing the survey contents
    prefix = '';
    contents.write(newLine('*end $surveyName', prefix));

    return contents.toString();
  }
}
