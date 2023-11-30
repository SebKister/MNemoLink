import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:characters/characters.dart';
import 'package:mnemolink/section.dart';
import 'package:mnemolink/sectionlist.dart';
import 'package:mnemolink/shot.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

      final Shots shots = getShots(section);
      final String contents =
          await getSvxContents(section, shots, filenameSuffix, unitType);
      final Uint8List contentsAsBytes = utf8.encode(contents);

      final String filename = "$baseFilename-$filenameSuffix.svx";
      final File file = File(filename);

      // await file.create(recursive: true);
      await file.writeAsBytes(contentsAsBytes);
    }
  }

  Shots getShots(Section section) {
    final List<Shot> shots = section.getShots();
    int id = 1;
    bool firstMeasurement = true;
    String connectingStation;
    double depthFrom = 0.0;
    double depthTo = 0.0;
    double depthToLast = 0.0;
    double azimuthNormalMeanPrevious = 0.0;
    List<ShotRegular> regularShots = [];
    List<ShotConnecting> connectingShots = [];

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

      double depthDelta = 0.0;
      List<String> depthComments = [];

      if (firstMeasurement) {
        firstMeasurement = false;
        depthDelta = 0.0;
        depthFrom = depthIn;
      } else {
        depthDelta = getDepthDelta(depthIn, depthToLast);
        depthComments = getDepthComment(depthDelta, depthIn, depthToLast);

        if (depthDelta > maxDeltaDepth) {
          depthFrom = depthIn;
        } else {
          depthFrom = (depthIn + depthToLast) / 2;
          regularShots[id - 2].depthTo = depthFrom;
        }

        azimuthNormalMeanPrevious =
            getAzimuthNormal(regularShots[id - 2].azimuthMean, azimuthMean);
      }
      depthTo = depthOut;

      if (depthDelta > maxDeltaDepth) {
        final String connectingStationFrom = id.toString();
        final String connectingStationTo = '${connectingStationFrom}B';
        final ShotConnecting connectingShot = ShotConnecting(
            from: connectingStationFrom,
            to: connectingStationTo,
            length: depthDelta,
            depthFrom: regularShots[id - 2].depthTo,
            depthTo: depthFrom);
        connectingShots.add(connectingShot);
        connectingStation = connectingStationTo;
      } else {
        connectingStation = '';
      }

      final ShotRegular regularShot = ShotRegular(
          from: connectingStation.isEmpty ? id.toString() : connectingStation,
          to: (id + 1).toString(),
          length: length,
          azimuthIn: azimuthIn,
          azimuthOut: azimuthOut,
          pitchIn: pitchIn,
          pitchOut: pitchOut,
          depthIn: depthIn,
          depthOut: depthOut,
          depthFrom: depthFrom,
          depthTo: depthTo,
          azimuthMean: azimuthMean,
          azimuthDelta: azimuthDelta,
          azimuthNormalMeanPrevious: azimuthNormalMeanPrevious,
          azimuthComments: azimuthComments,
          depthComments: depthComments);

      regularShots.add(regularShot);

      depthToLast = depthOut;
      id++;
    }

    final Shots processedShots =
        Shots(connectingShots: connectingShots, regularShots: regularShots);

    return processedShots;
  }

  double getAzimuthDelta(double angle1, double angle2) {
    double delta = (angle1 - angle2).abs();

    if (delta > 180) {
      delta = 360 - delta;
    }

    return delta;
  }

  double getDepthDelta(double depthIn, double depthOut) {
    final double delta = (depthIn - depthOut).abs();

    return delta;
  }

  List<String> getDepthComment(double delta, double depthIn, double depthOut) {
    List<String> comments = [];

    if (delta > maxDeltaDepth) {
      comments.add(
          'Depth delta WARNING: delta greater than ${maxDeltaDepth.toStringAsFixed(2)} (${delta.toStringAsFixed(2)}) between previous DepthOut (${depthOut.toStringAsFixed(2)}) and current DepthIn (${depthIn.toStringAsFixed(2)})');
      comments.add('-> Intermediate leg created below.');
    }

    // Uncomment and modify the following lines if needed
    // else {
    //   comments.add(
    //     'Depth delta (${delta.toStringAsFixed(2)}) between previous DepthOut (${depthOut.toStringAsFixed(2)}) and current DepthIn (${depthIn.toStringAsFixed(2)})'
    //   );
    // }

    return comments;
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

  double getAzimuthNormal(double azFrom, double azTo) {
    double delta = azTo - azFrom;

    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }

    double azMean = azFrom + (delta / 2);
    double azNormal;

    if (delta > 0) {
      azNormal = azMean + 90;
    } else {
      azNormal = azMean - 90;
    }

    if (azNormal > 360) {
      azNormal -= 360;
    } else if (azNormal < 0) {
      azNormal += 360;
    }

    return azNormal;
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

  String utf16ToAsciiTransliterate(String utf16String) {
    final Map<String, String> transliterationMap = {
      'Á': 'A',
      'á': 'a',
      'À': 'A',
      'à': 'a',
      'Â': 'A',
      'â': 'a',
      'Ä': 'A',
      'ä': 'a',
      'Ã': 'A',
      'ã': 'a',
      'Å': 'A',
      'å': 'a',
      'Ǎ': 'A',
      'ǎ': 'a',
      'Ą': 'A',
      'ą': 'a',
      'Ă': 'A',
      'ă': 'a',
      'Æ': 'AE',
      'æ': 'ae',
      'Ā': 'A',
      'ā': 'a',
      'Ç': 'C',
      'ç': 'c',
      'Ć': 'C',
      'ć': 'c',
      'Č': 'C',
      'č': 'c',
      'Ĉ': 'C',
      'ĉ': 'c',
      'Ċ': 'C',
      'ċ': 'c',
      'Ď': 'D',
      'ď': 'd',
      'Đ': 'D',
      'đ': 'd',
      'É': 'E',
      'é': 'e',
      'È': 'E',
      'è': 'e',
      'Ê': 'E',
      'ê': 'e',
      'Ë': 'E',
      'ë': 'e',
      'Ě': 'E',
      'ě': 'e',
      'Ę': 'E',
      'ę': 'e',
      'Ė': 'E',
      'ė': 'e',
      'Ē': 'E',
      'ē': 'e',
      'ƒ': 'f',
      'Ğ': 'G',
      'ğ': 'g',
      'Ĝ': 'G',
      'ĝ': 'g',
      'Ģ': 'G',
      'ģ': 'g',
      'Ġ': 'G',
      'ġ': 'g',
      'Ĥ': 'H',
      'ĥ': 'h',
      'Ħ': 'H',
      'ħ': 'h',
      'Í': 'I',
      'í': 'i',
      'Ì': 'I',
      'ì': 'i',
      'Î': 'I',
      'î': 'i',
      'Ï': 'I',
      'ï': 'i',
      'İ': 'I',
      'ı': 'i',
      'Ĩ': 'I',
      'ĩ': 'i',
      'Ī': 'I',
      'ī': 'i',
      'Ĭ': 'I',
      'ĭ': 'i',
      'Į': 'I',
      'į': 'i',
      'Ĳ': 'IJ',
      'ĳ': 'ij',
      'Ĵ': 'J',
      'ĵ': 'j',
      'Ķ': 'K',
      'ķ': 'k',
      'Ĺ': 'L',
      'ĺ': 'l',
      'Ľ': 'L',
      'ľ': 'l',
      'Ļ': 'L',
      'ļ': 'l',
      'Ł': 'L',
      'ł': 'l',
      'Ń': 'N',
      'ń': 'n',
      'Ň': 'N',
      'ň': 'n',
      'Ñ': 'N',
      'ñ': 'n',
      'Ņ': 'N',
      'ņ': 'n',
      'Ŋ': 'N',
      'ŋ': 'n',
      'Ó': 'O',
      'ó': 'o',
      'Ò': 'O',
      'ò': 'o',
      'Ô': 'O',
      'ô': 'o',
      'Ö': 'O',
      'ö': 'o',
      'Õ': 'O',
      'õ': 'o',
      'Ő': 'O',
      'ő': 'o',
      'Ø': 'O',
      'ø': 'o',
      'Œ': 'OE',
      'œ': 'oe',
      'Ō': 'O',
      'ō': 'o',
      'Ŕ': 'R',
      'ŕ': 'r',
      'Ř': 'R',
      'ř': 'r',
      'Ŗ': 'R',
      'ŗ': 'r',
      'Ś': 'S',
      'ś': 's',
      'Š': 'S',
      'š': 's',
      'Ş': 'S',
      'ş': 's',
      'Ș': 'S',
      'ș': 's',
      'Ŝ': 'S',
      'ŝ': 's',
      'ß': 'ss',
      'Ť': 'T',
      'ť': 't',
      'Ţ': 'T',
      'ţ': 't',
      'Ț': 'T',
      'ț': 't',
      'Ŧ': 'T',
      'ŧ': 't',
      'Ú': 'U',
      'ú': 'u',
      'Ù': 'U',
      'ù': 'u',
      'Û': 'U',
      'û': 'u',
      'Ü': 'U',
      'ü': 'u',
      'Ũ': 'U',
      'ũ': 'u',
      'Ů': 'U',
      'ů': 'u',
      'Ű': 'U',
      'ű': 'u',
      'Ū': 'U',
      'ū': 'u',
      'Ŭ': 'U',
      'ŭ': 'u',
      'Ų': 'U',
      'ų': 'u',
      'Ŵ': 'W',
      'ŵ': 'w',
      'Ý': 'Y',
      'ý': 'y',
      'Ÿ': 'Y',
      'ÿ': 'y',
      'Ŷ': 'Y',
      'ŷ': 'y',
      'Ź': 'Z',
      'ź': 'z',
      'Ž': 'Z',
      'ž': 'z',
      'Ż': 'Z',
      'ż': 'z',
    };

    final StringBuffer asciiBuffer = StringBuffer();

    for (final String char in utf16String.characters) {
      if (char.length == 1 &&
          char.runes.first >= 32 &&
          char.runes.first <= 127) {
        asciiBuffer.write(char);
      } else {
        asciiBuffer.write(transliterationMap[char] ??
            '?'); // Replace with '?' if no mapping is found
      }
    }

    return asciiBuffer.toString();
  }

  String slugify(String text, {String divider = '-'}) {
    // Replace non-letter or digits by divider
    text = text.replaceAll(RegExp(r'[^\p{L}\d]+', unicode: true), divider);

    // Dart doesn't have a direct equivalent of PHP's iconv transliteration,
    // so this step is skipped. You might use a package or custom logic for transliteration if needed.

    text = utf16ToAsciiTransliterate(text);

    // Remove unwanted characters
    text = text.replaceAll(RegExp(r'[^-\w]+'), '');

    // Trim
    text = text.trim().trimRight().trimLeft();

    // Remove duplicate divider
    text = text.replaceAll(RegExp(r'$divider+'), divider);

    // Lowercase
    text = text.toLowerCase();

    return text.isEmpty ? 'n-a' : text;
  }

  String dateInSvxFormat(DateTime date) {
    final String svxDate =
        "${date.year.toString().padLeft(4, '0')}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";

    return svxDate;
  }

  Future<String> getSvxContents(Section section, Shots shots, String surveyName,
      UnitType unitType) async {
    StringBuffer contents = StringBuffer(await headerComments());

    String prefix = '';
    contents.write(newLine('*begin $surveyName', prefix));

    prefix = '\t';
    contents.write(
        newLine('; First and last stations automatically exported', prefix));

    // Exporting first and last stations
    final int lastStation = shots.regularShots.length + 1;
    final String export = "1, ${lastStation.toString()}";
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

    contents.write(newLine('*case preserve', prefix));
    contents.write('\n');

    contents.write(newLine('*instrument compass MNemo', prefix));
    contents.write(newLine('*instrument clino MNemo', prefix));
    contents.write(newLine('*instrument tape MNemo', prefix));
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
        '; --------------------------------------------------', prefix));
    contents.write(newLine('; Main topo data', prefix));
    contents.write(newLine(
        '; --------------------------------------------------', prefix));
    contents.write(newLine(
        '*data diving from to tape compass fromdepth todepth ignoreall',
        prefix));
    contents.write(newLine(
        '; From\tTo\tLength\tAzimuth\tFromDep\tToDep\tAzIn\tAzOut\tAzDelta\tAzNormal\tDepIn\tDepOut\tPitchIn\tPitchOut',
        prefix));
    contents.write('\n');

    bool firstLine = true;
    for (ShotRegular shot in shots.regularShots) {
      if (shot.azimuthComments.isNotEmpty || shot.depthComments.isNotEmpty) {
        if (!firstLine) {
          contents.write('\n');
        }

        if (shot.azimuthComments.isNotEmpty) {
          for (var comment in shot.azimuthComments) {
            contents.write(newLine('; $comment', prefix));
          }
        }

        if (shot.depthComments.isNotEmpty) {
          for (String comment in shot.depthComments) {
            contents.write(newLine('; $comment', prefix));
          }
        }
      }

      // Formatting the measurement line
      contents.write(newLine(
          '${shot.from}\t${shot.to}\t${shot.length.toStringAsFixed(2)}\t${shot.azimuthMean.toStringAsFixed(1)}\t${shot.depthFrom.toStringAsFixed(2)}\t${shot.depthTo.toStringAsFixed(2)}\t${shot.azimuthIn.toStringAsFixed(1)}\t${shot.azimuthOut.toStringAsFixed(1)}\t${shot.azimuthDelta.toStringAsFixed(1)}\t${shot.azimuthNormalMeanPrevious.toStringAsFixed(1)}\t${shot.depthIn.toStringAsFixed(2)}\t${shot.depthOut.toStringAsFixed(2)}\t${shot.pitchIn.toStringAsFixed(1)}\t${shot.pitchOut.toStringAsFixed(1)}',
          prefix));
      firstLine = false;
    }
    contents.write('\n');

    // Connecting vertical legs
    if (shots.connectingShots.isNotEmpty) {
      contents.write(newLine(
          '; --------------------------------------------------', prefix));
      contents.write(newLine('; Connecting vertical legs', prefix));
      contents.write(newLine(
          '; --------------------------------------------------', prefix));
      contents.write(
          newLine('*data normal from to tape compass clino ignoreall', prefix));
      contents.write(newLine(
          '; From\tTo\tLength\tAzimuth\tUp/Down\tFromDep\tToDep', prefix));
      contents.write('\n');

      for (ShotConnecting shot in shots.connectingShots) {
        String direction = (shot.depthFrom < shot.depthTo) ? 'DOWN' : 'UP';
        contents.write(newLine(
            '${shot.from.toString().trim()}\t${shot.to.toString().trim()}\t${shot.length.toStringAsFixed(2)}\t-\t$direction\t${shot.depthFrom.toStringAsFixed(2)}\t${shot.depthTo.toStringAsFixed(2)}',
            prefix));
      }
      contents.write('\n');
    }

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

class ShotConnecting {
  String from;
  String to;
  double length;
  double depthFrom;
  double depthTo;

  ShotConnecting(
      {required this.from,
      required this.to,
      required this.length,
      required this.depthFrom,
      required this.depthTo});
}

class ShotRegular {
  String from;
  String to;
  double length;
  double azimuthIn;
  double azimuthOut;
  double pitchIn;
  double pitchOut;
  double depthIn;
  double depthOut;
  double depthFrom;
  double depthTo;
  double azimuthMean;
  double azimuthDelta;
  double azimuthNormalMeanPrevious;
  List<String> azimuthComments;
  List<String> depthComments;

  ShotRegular(
      {required this.from,
      required this.to,
      required this.length,
      required this.azimuthIn,
      required this.azimuthOut,
      required this.pitchIn,
      required this.pitchOut,
      required this.depthIn,
      required this.depthOut,
      required this.depthFrom,
      required this.depthTo,
      required this.azimuthMean,
      required this.azimuthDelta,
      required this.azimuthNormalMeanPrevious,
      required this.azimuthComments,
      required this.depthComments});
}

class Shots {
  List<ShotRegular> regularShots;
  List<ShotConnecting> connectingShots;

  Shots({required this.regularShots, required this.connectingShots});
}
