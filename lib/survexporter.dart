import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:mnemolink/section.dart';
import 'package:mnemolink/sectionlist.dart';
import 'package:mnemolink/shot.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slugify/slugify.dart';

class SurvexExporter {
  final int defaultFirstStationNumber = 1;
  final int minSectionCountWidth = 3;
  final double maxDeltaDepth = 0.2;
  final double maxDeltaAzimuth = 5;

  double getAzimuthMean(double az1, double az2) {
    // Convert degrees to radians
    final double az1Rad = deg2rad(az1);
    final double az2Rad = deg2rad(az2);

    // Calculate mean azimuth in radians
    final double meanSin = (sin(az1Rad) + sin(az2Rad)) / 2.0;
    final double meanCos = (cos(az1Rad) + cos(az2Rad)) / 2.0;
    final double meanAzimuthRad = atan2(meanSin, meanCos);

    // Convert the result back to degrees
    double meanAzimuthDeg = rad2deg(meanAzimuthRad);

    // Normalize the result to be within [0, 360) degrees
    if (meanAzimuthDeg < 0) {
      meanAzimuthDeg += 360.0;
    }

    return meanAzimuthDeg;
  }

  double deg2rad(double degrees) {
    return degrees * pi / 180.0;
  }

  double rad2deg(double radians) {
    return radians * 180.0 / pi;
  }

  Future<void> asSurvex(
      SectionList sectionList, String baseFilename, UnitType unitType) async {
    int fileCounter = 0;

    // Removing extension
    baseFilename = baseFilename.substring(0, baseFilename.length - 4);

    for (var section in sectionList.sections) {
      fileCounter++;
      String filenameSuffix =
          "${slugify(section.name)}-${fileCounter.toString().padLeft(minSectionCountWidth, '0')}";

      final SVXShots shots = getShots(section);
      final String contents =
          await getSvxContents(section, shots, filenameSuffix, unitType);
      final List<int> contentsAsBytes = utf8.encode(contents);

      final String filename = "$baseFilename-$filenameSuffix.svx";
      final File file = File(filename);

      // await file.create(recursive: true);
      await file.writeAsBytes(contentsAsBytes);
    }
  }

  SVXShots getShots(Section section) {
    final List<Shot> shots = section.getShots();
    int id = 1;
    List<SVXShot> svxShots = [];

    for (final shot in shots) {
      if (shot.typeShot != TypeShot.STD) {
        continue;
      }

      final double length = shot.getLength();
      final double azimuthIn = (shot.getHeadingIn().toDouble()) / 10.0;
      final double azimuthOut = (shot.getHeadingOut().toDouble()) / 10.0;
      final double azimuthMean = getAzimuthMean(azimuthIn, azimuthOut);
      final double azimuthDelta = getAzimuthDelta(azimuthIn, azimuthOut);
      final List<String> azimuthComments =
          getAzimuthComment(azimuthMean, azimuthDelta, azimuthIn, azimuthOut);
      final double pitchIn = (shot.getPitchIn().toDouble()) / 10.0;
      final double pitchOut = (shot.getPitchOut().toDouble()) / 10.0;
      final double depthIn = shot.getDepthIn();
      final double depthOut = shot.getDepthOut();

      final SVXShot svxShot = SVXShot(
          from: id.toString(),
          to: (id + 1).toString(),
          length: length,
          azimuthIn: azimuthIn,
          azimuthOut: azimuthOut,
          pitchIn: pitchIn,
          pitchOut: pitchOut,
          depthIn: depthIn,
          depthOut: depthOut,
          azimuthMean: azimuthMean,
          azimuthDelta: azimuthDelta,
          azimuthComments: azimuthComments);

      svxShots.add(svxShot);

      id++;
    }

    final SVXShots processedShots = SVXShots(svxShots: svxShots);

    return processedShots;
  }

  double getAzimuthDelta(double angle1, double angle2) {
    double delta = (angle1 - angle2).abs();

    if (delta > 180) {
      delta = 360 - delta;
    }

    return delta;
  }

  List<String> getAzimuthComment(double azimuthMean, double azimuthDelta,
      double azimuthIn, double azimuthOut) {
    List<String> comments = [];

    if (azimuthDelta > maxDeltaAzimuth) {
      comments.add(
          'Azimuth WARNING: difference between IN (${azimuthIn.toStringAsFixed(1)}) and OUT (${azimuthOut.toStringAsFixed(1)}) azimuths greater than limit (${maxDeltaAzimuth.toStringAsFixed(1)}): ${azimuthDelta.toStringAsFixed(1)}');
    }

    // Uncomment and modify the following line if needed
    // comments.add('Adopted azimuth mean: $azimuthMean');

    return comments;
  }

  Future<String> headerComments() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String version = packageInfo.version;

    String header = '''
; svx initially file created:
; * with MNemolink version $version
; * at ${DateTime.now().toIso8601String()}

''';

    return header;
  }

  String dateInSvxFormat(DateTime date) {
    final String svxDate =
        "${date.year.toString().padLeft(4, '0')}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";

    return svxDate;
  }

  Future<String> getSvxContents(Section section, SVXShots svxShots,
      String surveyName, UnitType unitType) async {
    StringBuffer contents = StringBuffer(await headerComments());

    String prefix = '';
    contents.write(newLine('*begin $surveyName', prefix));

    prefix = '\t';
    contents.write(
        newLine('; First and last stations automatically exported', prefix));

    // Exporting first and last stations
    final int lastStation = svxShots.svxShots.length + 1;
    final String export = "1 ${lastStation.toString()}";
    contents.write(newLine('*export $export', prefix));
    contents.write('\n');

    contents.write(newLine('*title "$surveyName"', prefix));
    contents.write('\n');

    contents
        .write(newLine('*date ${dateInSvxFormat(section.dateSurvey)}', prefix));
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
    for (SVXShot svxShot in svxShots.svxShots) {
      if (svxShot.azimuthComments.isNotEmpty) {
        if (!firstLine) {
          contents.write('\n');
        }

        for (var comment in svxShot.azimuthComments) {
          contents.write(newLine('; $comment', prefix));
        }
      }

      // Formatting the measurement line
      contents.write(newLine(
          '${svxShot.from}\t${svxShot.to}\t${svxShot.length.toStringAsFixed(2)}\t${svxShot.azimuthMean.toStringAsFixed(1)}\t${svxShot.depthIn.toStringAsFixed(2)}\t${svxShot.depthOut.toStringAsFixed(2)}\t${svxShot.azimuthIn.toStringAsFixed(1)}\t${svxShot.azimuthOut.toStringAsFixed(1)}\t${svxShot.azimuthDelta.toStringAsFixed(1)}\t${svxShot.pitchIn.toStringAsFixed(1)}\t${svxShot.pitchOut.toStringAsFixed(1)}',
          prefix));
      firstLine = false;
    }
    contents.write('\n');

    // Finalizing the survey contents
    prefix = '';
    contents.write(newLine('*end $surveyName', prefix));

    return contents.toString();
  }

  String newLine(String line, String prefix) {
    return '$prefix$line\n';
  }

  String getOutputFilename(String surveyName, String input) {
    String slugName =
        slugify(surveyName); // Implement `slugify` function in Dart
    String parts = Uri.parse(input).pathSegments.last;
    String output = '${parts}_$slugName.svx';

    return output;
  }
}

class SVXShot {
  String from;
  String to;
  double length;
  double azimuthIn;
  double azimuthOut;
  double pitchIn;
  double pitchOut;
  double depthIn;
  double depthOut;
  double azimuthMean;
  double azimuthDelta;
  List<String> azimuthComments;

  SVXShot(
      {required this.from,
      required this.to,
      required this.length,
      required this.azimuthIn,
      required this.azimuthOut,
      required this.pitchIn,
      required this.pitchOut,
      required this.depthIn,
      required this.depthOut,
      required this.azimuthMean,
      required this.azimuthDelta,
      required this.azimuthComments});
}

class SVXShots {
  List<SVXShot> svxShots;

  SVXShots({required this.svxShots});
}
