import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mnemolink/section.dart';
import 'package:mnemolink/sectionlist.dart';
import 'package:mnemolink/shot.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slugify/slugify.dart';

mixin ShotExport {
  final int _minSectionCountWidth = 3;

  // Same value used by Therion
  final double _maxDeltaAzimuth = 3;

  String _prefix = '';

  String get extension;

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

  void increasePrefix() {
    _prefix += '  ';
  }

  void decreasePrefix() {
    _prefix = _prefix.substring(2);
  }

  double deg2rad(double degrees) {
    return degrees * pi / 180.0;
  }

  double rad2deg(double radians) {
    return radians * 180.0 / pi;
  }

  double getAzimuthDelta(double angle1, double angle2) {
    double delta = (angle1 - angle2).abs();

    if (delta > 180) {
      delta = 360 - delta;
    }

    return delta;
  }

  Future<String> getContents(Section section, ExportShots exportShots,
      String surveyName, UnitType unitType);

  Future<void> export(
      SectionList sectionList, String baseFilename, UnitType unitType) async {
    int fileCounter = 0;

    // Removing extension
    baseFilename =
        baseFilename.substring(0, baseFilename.length - extension.length);

    for (var section in sectionList.sections) {
      fileCounter++;
      String filenameSuffix =
          "${slugify(section.name)}-${fileCounter.toString().padLeft(_minSectionCountWidth, '0')}";

      final ExportShots shots = getShots(section);
      final String contents =
          await getContents(section, shots, filenameSuffix, unitType);
      final List<int> contentsAsBytes = utf8.encode(contents);

      final String filename = "$baseFilename-$filenameSuffix$extension";
      final File file = File(filename);

      // await file.create(recursive: true);
      await file.writeAsBytes(contentsAsBytes);
    }
  }

  List<String> getAzimuthComment(double azimuthMean, double azimuthDelta,
      double azimuthIn, double azimuthOut) {
    List<String> comments = [];

    if (azimuthDelta > _maxDeltaAzimuth) {
      comments.add(
          'Azimuth WARNING: difference between IN (${azimuthIn.toStringAsFixed(1)}) and OUT (${azimuthOut.toStringAsFixed(1)}) azimuths greater than limit (${_maxDeltaAzimuth.toStringAsFixed(1)}): ${azimuthDelta.toStringAsFixed(1)}');
    }

    return comments;
  }

  ExportShots getShots(Section section) {
    final List<Shot> shots = section.getShots();
    int id = 1;
    List<ExportShot> svxShots = [];

    for (final shot in shots) {
      if (shot.typeShot != TypeShot.std) {
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

      final ExportShot svxShot = ExportShot(
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

    final ExportShots processedShots = ExportShots(shots: svxShots);

    return processedShots;
  }

  String newLine(String line) {
    return '$_prefix$line\n';
  }

  String dateInExportFormat(DateTime date) {
    final String svxDate =
        "${date.year.toString().padLeft(4, '0')}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";

    return svxDate;
  }

  String dateInWallsFormat(DateTime date) {
    final String wallsDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    return wallsDate;
  }

  Future<String> getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    final String version = packageInfo.version;

    return version;
  }
}

class ExportShot {
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

  ExportShot(
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

class ExportShots {
  List<ExportShot> shots;

  ExportShots({required this.shots});
}
