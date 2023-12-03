import 'package:mnemolink/section.dart';
import 'package:mnemolink/shot.dart';
import 'package:mnemolink/shotexport.dart';

class THExporter with ShotExport {
  @override
  String get extension => '.th';

  @override
  Future<String> getContents(Section section, ExportShots exportShots,
      String surveyName, UnitType unitType) async {
    StringBuffer contents = StringBuffer(await headerComments());

    contents.write(newLine('survey $surveyName'));

    increasePrefix();
    contents.write(newLine('centreline'));
    contents.write('\n');

    increasePrefix();
    contents.write(newLine('date ${dateInExportFormat(section.dateSurvey)}'));
    contents.write('\n');

    // Additional contents based on data
    contents.write(newLine(
        '# Uncomment and fill the lines below to set the team members names.'));
    contents.write(newLine('#team ""'));
    contents.write(newLine('#explo-date ""'));
    contents.write(newLine('#explo-team ""'));
    contents.write('\n');

    contents.write(newLine('instrument compass "MNemo V2"'));
    contents.write(newLine('instrument depth "MNemo V2"'));
    contents.write(newLine('instrument tape "MNemo V2"'));
    contents.write('\n');

    contents.write(newLine('sd compass 1.5 degrees'));
    contents.write(newLine('sd depth 0.1 metres'));
    contents.write(newLine('sd tape 0.086 metres'));
    contents.write('\n');

    contents.write(newLine('calibrate depth 0 -1'));
    contents.write('\n');

    // Unit handling
    if (unitType == UnitType.METRIC) {
      contents.write(newLine('units tape depth metres'));
    } else {
      contents.write(newLine('units tape depth feet'));
    }
    contents.write('\n');

    // Main topo data
    contents.write(newLine(
        'data diving from to tape compass fromdepth todepth ignoreall'));
    contents.write(newLine(
        '# From\tTo\tLength\tAzimuth\tDepIn\tDepOut\tAzIn\tAzOut\tAzDelta\tPitchIn\tPitchOut'));
    contents.write('\n');

    increasePrefix();
    bool firstLine = true;
    for (ExportShot exportShot in exportShots.shots) {
      if (exportShot.azimuthComments.isNotEmpty) {
        if (!firstLine) {
          contents.write('\n');
        }

        for (var comment in exportShot.azimuthComments) {
          contents.write(newLine('# $comment'));
        }
      }

      // Formatting the measurement line
      contents.write(newLine(
          '${exportShot.from}\t${exportShot.to}\t${exportShot.length.toStringAsFixed(2)}\t${exportShot.azimuthMean.toStringAsFixed(1)}\t${exportShot.depthIn.toStringAsFixed(2)}\t${exportShot.depthOut.toStringAsFixed(2)}\t${exportShot.azimuthIn.toStringAsFixed(1)}\t${exportShot.azimuthOut.toStringAsFixed(1)}\t${exportShot.azimuthDelta.toStringAsFixed(1)}\t${exportShot.pitchIn.toStringAsFixed(1)}\t${exportShot.pitchOut.toStringAsFixed(1)}'));
      firstLine = false;
    }
    contents.write('\n');
    decreasePrefix();

    decreasePrefix();
    contents.write(newLine('endcentreline'));

    // Finalizing the survey contents
    decreasePrefix();
    contents.write(newLine('endsurvey $surveyName'));

    return contents.toString();
  }

  Future<String> headerComments() async {
    final String version = await getAppVersion();

    String header = '''
# th file initially created:
# * with MNemolink version $version
# * at ${DateTime.now().toIso8601String()}

''';

    return header;
  }
}
