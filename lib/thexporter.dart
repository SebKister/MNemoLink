import 'models/models.dart';
import 'shotexport.dart';

class THExporter with ShotExport {
  @override
  String get extension => '.th';

  @override
  Future<String> getContents(Section section, ExportShots exportShots,
      String surveyName, UnitType unitType) async {
    StringBuffer contents = StringBuffer(newLine('encoding UTF-8'));
    StringBuffer lurdContents = StringBuffer();

    contents.write('\n');

    contents.write(await headerComments());

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
    if (unitType == UnitType.metric) {
      contents.write(newLine('units tape depth metres'));
    } else {
      contents.write(newLine('units tape depth feet'));
    }
    contents.write('\n');

    // Main topo data
    contents.write(newLine(
        'data diving from to tape compass backcompass fromdepth todepth ignoreall'));
    contents.write(newLine(
        '# From\tTo\tLength\tAzIn\t180-AzOut\tDepIn\tDepOut\tAzMean\tAzOut\tAzDelta\tPitchIn\tPitchOut'));
    contents.write('\n');

    increasePrefix();
    bool firstLine = true;
    for (ExportShot exportShot in exportShots.shots) {
      if (exportShot.azimuthComments.isNotEmpty || exportShot.isCalculatedLength) {
        if (!firstLine) {
          contents.write('\n');
        }

        for (var comment in exportShot.azimuthComments) {
          contents.write(newLine('# $comment'));
        }
        
        if (exportShot.isCalculatedLength) {
          contents.write(newLine('# Length calculated from depth change and inclination (original measurement was insufficient)'));
        }
      }

      // Formatting the measurement line
      contents.write(newLine(
          '${exportShot.from}\t${exportShot.to}\t${exportShot.length.toStringAsFixed(2)}\t${exportShot.azimuthIn.toStringAsFixed(1)}\t${exportShot.azimuthOut180.toStringAsFixed(1)}\t${exportShot.depthIn.toStringAsFixed(2)}\t${exportShot.depthOut.toStringAsFixed(2)}\t${exportShot.azimuthMean.toStringAsFixed(1)}\t${exportShot.azimuthOut.toStringAsFixed(1)}\t${exportShot.azimuthDelta.toStringAsFixed(1)}\t${exportShot.pitchIn.toStringAsFixed(1)}\t${exportShot.pitchOut.toStringAsFixed(1)}'));

      if (exportShot.lurdShots.isNotEmpty) {
        lurdContents.write(newLine('# LURD for station ${exportShot.to}'));
        for (LURDShot lurdShot in exportShot.lurdShots) {
          lurdContents.write(newLine(
              '# ${enumToStringWithoutClassName(lurdShot.direction.toString())}'));
          lurdContents.write(newLine(
              '${exportShot.to}\t-\t${lurdShot.length.toStringAsFixed(2)}\t${lurdShot.azimuth.toStringAsFixed(1)}\t${lurdShot.clino.toStringAsFixed(1)}'));
        }
        lurdContents.write('\n');
      }

      firstLine = false;
    }
    contents.write('\n');

    if (lurdContents.isNotEmpty) {
      contents.write(newLine('# LURD measurements'));
      contents.write(newLine('data normal from to tape compass clino'));
      contents.write('\n');
      contents.write(lurdContents.toString());
    }

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
