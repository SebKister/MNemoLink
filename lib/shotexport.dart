import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_numerics/dart_numerics.dart';
import 'models/models.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slugify/slugify.dart';

mixin ShotExport {
  final int _minSectionCountWidth = 3;

  // Same value used by Therion
  final double _maxDeltaAzimuth = 3;

  String _prefix = '';

  String get extension;

  /// Check if a section contains Lidar data (indicating dry cave survey)
  bool hasDryCaveSurvey(Section section) {
    return section.getShots().any((shot) => shot.hasLidarData());
  }

  /// Generate instrument configuration for survey type
  void writeInstrumentConfig(
    StringBuffer contents,
    bool isDryCave,
    String prefix, // '' for Therion, '*' for Survex
  ) {
    if (isDryCave) {
      contents.write(newLine('${prefix}instrument compass "Jedeye"'));
      contents.write(newLine('${prefix}instrument clino "Jedeye"'));
      contents.write(newLine('${prefix}instrument tape "Jedeye"'));
    } else {
      contents.write(newLine('${prefix}instrument compass "MNemo V2"'));
      contents.write(newLine('${prefix}instrument depth "MNemo V2"'));
      contents.write(newLine('${prefix}instrument tape "MNemo V2"'));
    }
    contents.write('\n');

    contents.write(newLine('${prefix}sd compass 1.5 degrees'));
    contents.write(newLine('${prefix}sd tape 0.086 metres'));
    if (!isDryCave) {
      contents.write(newLine('${prefix}sd depth 0.1 metres'));
    }
    contents.write('\n');

    if (!isDryCave) {
      contents.write(newLine('${prefix}calibrate depth 0 -1'));
      contents.write('\n');
    }
  }

  /// Generate units configuration for survey type
  void writeUnitsConfig(
    StringBuffer contents,
    bool isDryCave,
    UnitType unitType,
    String prefix, // '' for Therion, '*' for Survex
  ) {
    if (isDryCave) {
      // Dry cave: no depth measurements
      if (unitType == UnitType.metric) {
        contents.write(newLine('${prefix}units tape metres'));
      } else {
        contents.write(newLine('${prefix}units tape feet'));
      }
      contents.write(newLine('${prefix}units clino deg'));
    } else {
      // Underwater survey: include depth
      if (unitType == UnitType.metric) {
        contents.write(newLine('${prefix}units tape depth metres'));
      } else {
        contents.write(newLine('${prefix}units tape depth feet'));
      }
    }
    contents.write('\n');
  }

  /// Generate data format configuration for survey type
  void writeDataConfig(
    StringBuffer contents,
    bool isDryCave,
    String prefix, // '' for Therion, '*' for Survex
    String commentPrefix, // '#' for Therion, ';' for Survex
  ) {
    if (isDryCave) {
      // Dry cave data format
      final dryDataFormat = [
        '${prefix}data',
        'normal',
        'from',
        'to',
        'tape',
        'compass',
        'backcompass',
        'clino',
        'backclino',
        'ignoreall'
      ].join(' ');

      final dryHeaderFormat = [
        '$commentPrefix From',
        'To',
        'Length',
        'AzIn',
        '180-AzOut',
        'PitchIn',
        'PitchOut',
        'AzMean',
        'AzOut',
        'AzDelta'
      ].join('\t');

      contents.write(newLine(dryDataFormat));
      contents.write(newLine(dryHeaderFormat));
    } else {
      // Underwater data format
      final underwaterDataFormat = [
        '${prefix}data',
        'diving',
        'from',
        'to',
        'tape',
        'compass',
        'backcompass',
        'fromdepth',
        'todepth',
        'ignoreall'
      ].join(' ');

      final underwaterHeaderFormat = [
        '$commentPrefix From',
        'To',
        'Length',
        'AzIn',
        '180-AzOut',
        'DepIn',
        'DepOut',
        'AzMean',
        'AzOut',
        'AzDelta',
        'PitchIn',
        'PitchOut'
      ].join('\t');

      contents.write(newLine(underwaterDataFormat));
      contents.write(newLine(underwaterHeaderFormat));
    }
    contents.write('\n');
  }

  /// Format shot data line for export
  String formatShotDataLine(
    ExportShot exportShot,
    bool isDryCave,
    int paddingWidth,
  ) {
    final String fromStation = exportShot.from.padLeft(paddingWidth, '0');
    final String toStation = exportShot.to.padLeft(paddingWidth, '0');

    if (isDryCave) {
      return [
        fromStation,
        toStation,
        exportShot.length.toStringAsFixed(2),
        exportShot.azimuthIn.toStringAsFixed(1),
        exportShot.azimuthOut180.toStringAsFixed(1),
        exportShot.pitchIn.toStringAsFixed(1),
        exportShot.pitchOut.toStringAsFixed(1),
        exportShot.azimuthMean.toStringAsFixed(1),
        exportShot.azimuthOut.toStringAsFixed(1),
        exportShot.azimuthDelta.toStringAsFixed(1),
      ].join('\t');
    } else {
      return [
        fromStation,
        toStation,
        exportShot.length.toStringAsFixed(2),
        exportShot.azimuthIn.toStringAsFixed(1),
        exportShot.azimuthOut180.toStringAsFixed(1),
        exportShot.depthIn.toStringAsFixed(2),
        exportShot.depthOut.toStringAsFixed(2),
        exportShot.azimuthMean.toStringAsFixed(1),
        exportShot.azimuthOut.toStringAsFixed(1),
        exportShot.azimuthDelta.toStringAsFixed(1),
        exportShot.pitchIn.toStringAsFixed(1),
        exportShot.pitchOut.toStringAsFixed(1),
      ].join('\t');
    }
  }

  /// Process LRUD and Lidar data for an export shot
  /// Returns a map with 'lrud' and 'lidar' StringBuffer contents
  Map<String, StringBuffer> processLRUDAndLidarData(
    ExportShot exportShot,
    bool isDryCave,
    int paddingWidth,
    String commentPrefix,
    String Function(String) stationNameFormatter,
  ) {
    final Map<String, StringBuffer> result = {
      'lrud': StringBuffer(),
      'lidar': StringBuffer(),
    };

    if (exportShot.lrudShots.isEmpty) return result;

    final String stationName = stationNameFormatter(exportShot.to);

    // Separate regular LRUD from Lidar data
    final List<LRUDShot> regularLrudShots = exportShot.lrudShots
        .where((shot) => shot.direction != LRUDDirection.lidar)
        .toList();
    final List<LRUDShot> lidarShots = exportShot.lrudShots
        .where((shot) => shot.direction == LRUDDirection.lidar)
        .toList();

    // Process regular LRUD measurements
    if (regularLrudShots.isNotEmpty) {
      result['lrud']!.write(newLine('$commentPrefix LRUD for station $stationName'));
      for (LRUDShot lrudShot in regularLrudShots) {
        result['lrud']!.write(newLine(
            '$commentPrefix ${enumToStringWithoutClassName(lrudShot.direction.toString())}'));

        final lrudDataLine = [
          stationName,
          '-',
          lrudShot.length.toStringAsFixed(2),
          lrudShot.azimuth.toStringAsFixed(1),
          lrudShot.clino.toStringAsFixed(1)
        ].join('\t');

        result['lrud']!.write(newLine(lrudDataLine));
      }
      result['lrud']!.write('\n');
    }

    // Process Lidar measurements
    if (lidarShots.isNotEmpty && isDryCave) {
      result['lidar']!.write(newLine('$commentPrefix Lidar measurements from station $stationName'));
      for (LRUDShot lidarShot in lidarShots) {
        final lidarDataLine = [
          stationName,
          '-',
          lidarShot.length.toStringAsFixed(2),
          lidarShot.azimuth.toStringAsFixed(1),
          lidarShot.clino.toStringAsFixed(1)
        ].join('\t');

        result['lidar']!.write(newLine(lidarDataLine));
      }
      result['lidar']!.write('\n');
    }

    return result;
  }

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

      final double length = shot.getCalculatedLength();
      final double azimuthIn = shot.getHeadingIn();
      final double azimuthOut = shot.getHeadingOut();
      final double azimuthMean = getAzimuthMean(azimuthIn, azimuthOut);
      final double azimuthDelta = getAzimuthDelta(azimuthIn, azimuthOut);
      final List<String> azimuthComments =
          getAzimuthComment(azimuthMean, azimuthDelta, azimuthIn, azimuthOut);
      final double pitchIn = shot.getPitchIn();
      final double pitchOut = shot.getPitchOut();
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
          lrudLeft: shot.getLeft(),
          lrudRight: shot.getRight(),
          lrudUp: shot.getUp(),
          lrudDown: shot.getDown(),
          azimuthComments: azimuthComments,
          isCalculatedLength: shot.usesCalculatedLength(),
          lidarData: shot.lidarData);

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
  late double azimuthOut180;
  double pitchIn;
  double pitchOut;
  double depthIn;
  double depthOut;
  double azimuthMean;
  double azimuthDelta;
  late List<LRUDShot> lrudShots;
  List<String> azimuthComments;
  bool isCalculatedLength;

  ExportShot({
    required this.from,
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
    required double lrudLeft,
    required double lrudRight,
    required double lrudUp,
    required double lrudDown,
    required this.azimuthComments,
    required this.isCalculatedLength,
    LidarData? lidarData,
  }) {
    azimuthOut180 = (azimuthOut + 180) % 360;
    lrudShots = [];
    if (!almostEqual(0.0, lrudLeft)) {
      lrudShots.add(
        LRUDShot(
          direction: LRUDDirection.left,
          length: lrudLeft,
          azimuth: _addAngles(azimuthMean, -90.0),
          clino: 0.0,
        ),
      );
    }
    if (!almostEqual(0.0, lrudRight)) {
      lrudShots.add(
        LRUDShot(
          direction: LRUDDirection.right,
          length: lrudRight,
          azimuth: _addAngles(azimuthMean, 90.0),
          clino: 0.0,
        ),
      );
    }
    if (!almostEqual(0.0, lrudUp)) {
      lrudShots.add(
        LRUDShot(
          direction: LRUDDirection.up,
          length: lrudUp,
          azimuth: 0.0,
          clino: 90.0,
        ),
      );
    }
    if (!almostEqual(0.0, lrudDown)) {
      lrudShots.add(
        LRUDShot(
          direction: LRUDDirection.down,
          length: lrudDown,
          azimuth: 0.0,
          clino: -90.0,
        ),
      );
    }

    // Process Lidar data as LRUD shots
    if (lidarData != null && lidarData.hasData) {
      for (final point in lidarData.points) {
        lrudShots.add(
          LRUDShot(
            direction: LRUDDirection.lidar,
            length: point.distance,
            azimuth: point.yaw,
            clino: point.pitch,
          ),
        );
      }
    }
  }

  double _addAngles(double angle, double delta) {
    double newAngle = angle + delta;

    if (newAngle >= 360) {
      newAngle -= 360;
    } else if (newAngle < 0) {
      newAngle += 360;
    }

    return newAngle;
  }
}

class ExportShots {
  List<ExportShot> shots;

  ExportShots({required this.shots});
}

String enumToStringWithoutClassName(dynamic enumValue) {
  return enumValue.toString().split('.').last;
}

class LRUDShot {
  LRUDDirection direction;
  double length;
  double azimuth;
  double clino;

  LRUDShot({
    required this.direction,
    required this.length,
    required this.azimuth,
    required this.clino,
  });
}

enum LRUDDirection { left, right, up, down, lidar }
