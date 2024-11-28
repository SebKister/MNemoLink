import 'package:mnemolink/section.dart';
import 'package:mnemolink/shot.dart';
import 'package:mnemolink/shotexport.dart';

class WallsExporter with ShotExport {
  @override
  String get extension => '.SRV';

  Future<String> headerComments() async {
    final String version = await getAppVersion();

    String header = '''
; walls export file initially created:
; * with MNemolink version $version
; * at ${DateTime.now().toIso8601String()}

; Cave notes:
; CAVE NAME
; PASSAGE LOCATION AND DESCRIPTION
; PARTICIPANTS
; OTHER NOTEABLE ITEMS

''';

    return header;
  }

  @override
  Future<String> getContents(Section section, ExportShots exportShots,
      String surveyName, UnitType unitType) async {
    StringBuffer contents = StringBuffer(await headerComments());

    contents.write(newLine('#DATE ${dateInWallsFormat(section.dateSurvey)}'));
    contents.write(newLine('#PREFIX CHANGE_ME'));
    contents.write('\n');

    // Unit handling
    if (unitType == UnitType.metric) {
      contents.write(newLine('#UNITS meters ORDER=DA tape=SS'));
    } else {
      contents.write(newLine('#UNITS feet ORDER=DA tape=SS'));
    }
    contents.write('\n');

    // Exporting first and last stations
    final int lastStation = exportShots.shots.length + 1;
    final String export = "1 ${lastStation.toString()}";
    contents.write('\n');

   // Main topo data
    contents.write(newLine('; from\tto\tdist\taz\tdepth1\tdepth2'));
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
          '${exportShot.from}\t${exportShot.to}\t${exportShot.length.toStringAsFixed(2)}\t${exportShot.azimuthMean.toStringAsFixed(1)}\t${exportShot.depthIn.toStringAsFixed(2)}\t${exportShot.depthOut.toStringAsFixed(2)}'));
      firstLine = false;
    }
    contents.write('\n');

    return contents.toString();
  }
}
