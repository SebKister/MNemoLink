import 'models/models.dart';
import 'shotexport.dart';

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
    StringBuffer lrudContents = StringBuffer();

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

    final bool isDryCave = hasDryCaveSurvey(section);

    // Write configuration using shared methods
    writeInstrumentConfig(contents, isDryCave, '*');
    writeUnitsConfig(contents, isDryCave, unitType, '*');
    writeDataConfig(contents, isDryCave, '*', ';');

    // Calculate padding width for station names based on total number of stations
    final int paddingWidth = (exportShots.shots.length + 1).toString().length;

    bool firstLine = true;
    for (ExportShot exportShot in exportShots.shots) {
      if (exportShot.azimuthComments.isNotEmpty || exportShot.isCalculatedLength) {
        if (!firstLine) {
          contents.write('\n');
        }

        for (var comment in exportShot.azimuthComments) {
          contents.write(newLine('; $comment'));
        }

        if (exportShot.isCalculatedLength) {
          contents.write(newLine('; Length calculated from depth change and inclination (original measurement was insufficient)'));
        }
      }

      // Formatting the measurement line
      contents.write(newLine(formatShotDataLine(exportShot, isDryCave, paddingWidth)));

      final Map<String, StringBuffer> lrudData = processLRUDAndLidarData(
        exportShot,
        isDryCave,
        paddingWidth,
        ';',
        (stationTo) => stationTo.padLeft(paddingWidth, '0'),
      );

      lrudContents.write(lrudData['lrud']!.toString());
      lrudContents.write(lrudData['lidar']!.toString());

      firstLine = false;
    }
    contents.write('\n');

    if (lrudContents.isNotEmpty) {
      contents.write(newLine('; LRUD measurements'));
      contents.write(newLine('*data normal from to tape compass clino'));
      contents.write('\n');
      contents.write(lrudContents.toString());
    }

    // Finalizing the survey contents
    decreasePrefix();
    contents.write(newLine('*end $surveyName'));

    return contents.toString();
  }
}
