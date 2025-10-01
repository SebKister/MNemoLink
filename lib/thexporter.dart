import 'models/models.dart';
import 'shotexport.dart';

class THExporter with ShotExport {
  @override
  String get extension => '.th';


  @override
  Future<String> getContents(Section section, ExportShots exportShots,
      String surveyName, UnitType unitType) async {
    StringBuffer contents = StringBuffer(newLine('encoding UTF-8'));
    StringBuffer lrudContents = StringBuffer();

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

    final bool isDryCave = hasDryCaveSurvey(section);

    // Write configuration using shared methods
    writeInstrumentConfig(contents, isDryCave, '');
    writeUnitsConfig(contents, isDryCave, unitType, '');
    writeDataConfig(contents, isDryCave, '', '#');

    increasePrefix();

    // Calculate padding width for station names based on total number of stations
    final int paddingWidth = isDryCave ? (exportShots.shots.length + 1).toString().length : 0;

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
      contents.write(newLine(formatShotDataLine(exportShot, isDryCave, paddingWidth)));

      final Map<String, StringBuffer> lrudData = processLRUDAndLidarData(
        exportShot,
        isDryCave,
        paddingWidth,
        '#',
        (stationTo) => stationTo.padLeft(paddingWidth, '0'),
      );

      lrudContents.write(lrudData['lrud']!.toString());
      lrudContents.write(lrudData['lidar']!.toString());

      firstLine = false;
    }
    contents.write('\n');

    if (lrudContents.isNotEmpty) {
      contents.write(newLine('# LRUD measurements'));
      contents.write(newLine('data normal from to tape compass clino'));
      contents.write('\n');
      contents.write(lrudContents.toString());
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
