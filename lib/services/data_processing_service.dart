import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Service for processing MNemo binary data and converting to survey models
class DataProcessingService {
  // File format constants
  static const int _fileVersionValueA = 68;
  static const int _fileVersionValueB = 89;
  static const int _fileVersionValueC = 101;
  
  static const int _shotStartValueA = 57;
  static const int _shotStartValueB = 67;
  static const int _shotStartValueC = 77;
  
  static const int _shotEndValueA = 95;
  static const int _shotEndValueB = 25;
  static const int _shotEndValueC = 35;

  // V6 format Lidar data constants
  static const int _lidarStartValueA = 32;
  static const int _lidarStartValueB = 33;
  static const int _lidarStartValueC = 34;

  /// Process raw binary transfer buffer into survey sections
  Future<DataProcessingResult> processTransferBuffer(
    List<int> transferBuffer,
    UnitType unitType
  ) async {
    try {
      final sections = <Section>[];
      int cursor = 0;
      bool brokenSegmentDetected = false;

      final conversionFactor = unitType == UnitType.metric ? 1.0 : 3.28084;

      while (cursor < transferBuffer.length - 2) {
        final sectionResult = await _processSection(
          transferBuffer,
          cursor,
          conversionFactor
        );

        if (sectionResult.section != null) {
          sections.add(sectionResult.section!);
        }

        cursor = sectionResult.newCursor;

        if (sectionResult.brokenSegment) {
          brokenSegmentDetected = true;
        }

        if (sectionResult.shouldStop) {
          break;
        }
      }

      return DataProcessingResult.success(
        sections,
        brokenSegmentDetected: brokenSegmentDetected
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error processing transfer buffer: $e");
      }
      return DataProcessingResult.error("Failed to process data: $e");
    }
  }

  /// Process a single section from the transfer buffer
  Future<_SectionProcessingResult> _processSection(
    List<int> transferBuffer,
    int startCursor,
    double conversionFactor,
  ) async {
    int cursor = startCursor;
    final section = Section();
    bool brokenSegment = false;

    if (kDebugMode) {
      debugPrint("DataProcessingService: Starting new section at cursor $cursor");
    }

    // Find file version
    int fileVersion = 0;
    while (fileVersion != 2 && fileVersion != 3 && fileVersion != 4 && fileVersion != 5 && fileVersion != 6) {
      if (cursor >= transferBuffer.length) {
        return _SectionProcessingResult(null, cursor, false, true);
      }
      fileVersion = _readByteFromBuffer(transferBuffer, cursor);
      cursor++;
    }

    // Validate file version magic bytes for version 5+
    if (fileVersion >= 5) {
      if (cursor + 2 >= transferBuffer.length) {
        return _SectionProcessingResult(null, cursor, false, true);
      }
      
      final checkByteA = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteB = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteC = _readByteFromBuffer(transferBuffer, cursor++);
      
      if (checkByteA != _fileVersionValueA ||
          checkByteB != _fileVersionValueB ||
          checkByteC != _fileVersionValueC) {
        if (kDebugMode) {
          debugPrint("DataProcessingService: Invalid file version magic bytes");
        }
        return _SectionProcessingResult(null, cursor, false, true);
      }
    }

    // Read section metadata
    if (cursor + 8 >= transferBuffer.length) {
      return _SectionProcessingResult(null, cursor, false, true);
    }

    final year = _readByteFromBuffer(transferBuffer, cursor++) + 2000;
    final month = _readByteFromBuffer(transferBuffer, cursor++);
    final day = _readByteFromBuffer(transferBuffer, cursor++);
    final hour = _readByteFromBuffer(transferBuffer, cursor++);
    final minute = _readByteFromBuffer(transferBuffer, cursor++);
    
    section.dateSurvey = DateTime(year, month, day, hour, minute);

    // Read section name (3 characters)
    final nameBuilder = StringBuffer();
    for (int i = 0; i < 3; i++) {
      if (cursor >= transferBuffer.length) {
        return _SectionProcessingResult(null, cursor, false, true);
      }
      nameBuilder.write(utf8.decode([_readByteFromBuffer(transferBuffer, cursor++)]));
    }
    section.name = nameBuilder.toString();

    // Read direction
    if (cursor >= transferBuffer.length) {
      return _SectionProcessingResult(null, cursor, false, true);
    }
    
    final directionIndex = _readByteFromBuffer(transferBuffer, cursor++);
    if (directionIndex == 0 || directionIndex == 1) {
      section.direction = SurveyDirection.values[directionIndex];
    } else {
      if (kDebugMode) {
        debugPrint("DataProcessingService: Invalid direction index: $directionIndex");
      }
      return _SectionProcessingResult(null, cursor, false, true);
    }

    if (kDebugMode) {
      debugPrint("DataProcessingService: Section ${section.name}, "
          "date: ${section.dateSurvey}, direction: ${section.direction}");
    }

    // Process shots
    Shot shot;
    do {
      final shotResult = await _processShot(
        transferBuffer, 
        cursor, 
        fileVersion, 
        conversionFactor
      );
      
      shot = shotResult.shot;
      cursor = shotResult.newCursor;
      
      if (shotResult.brokenSegment) {
        section.brokenFlag = true;
        brokenSegment = true;
        break;
      }
      
      section.shots.add(shot);
      
    } while (shot.typeShot != TypeShot.eoc && cursor < transferBuffer.length);

    // Only add section if it contains actual data (more than just EOC shot)
    if (section.shots.length > 1) {
      if (kDebugMode) {
        debugPrint("DataProcessingService: Completed section with ${section.shots.length} shots");
      }
      return _SectionProcessingResult(section, cursor, brokenSegment, false);
    } else {
      return _SectionProcessingResult(null, cursor, brokenSegment, false);
    }
  }

  /// Process a single shot from the transfer buffer
  Future<_ShotProcessingResult> _processShot(
    List<int> transferBuffer,
    int startCursor,
    int fileVersion,
    double conversionFactor,
  ) async {
    int cursor = startCursor;
    final shot = Shot.zero();


    // Validate shot start magic bytes for version 5+
    if (fileVersion >= 5) {
      if (cursor + 2 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }
      
      final checkByteA = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteB = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteC = _readByteFromBuffer(transferBuffer, cursor++);
      
      if (checkByteA != _shotStartValueA ||
          checkByteB != _shotStartValueB ||
          checkByteC != _shotStartValueC) {
        if (kDebugMode) {
          debugPrint("DataProcessingService: Invalid shot start magic bytes");
        }
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor - 3, true);
      }
    }

    // Read shot type
    if (cursor >= transferBuffer.length) {
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }
    
    final typeShot = _readByteFromBuffer(transferBuffer, cursor++);
    if (typeShot > 3 || typeShot < 0) {
      if (kDebugMode) {
        debugPrint("DataProcessingService: Invalid shot type: $typeShot");
      }
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }
    
    shot.typeShot = TypeShot.values[typeShot];

  // This is handling broken sample file I got. Might not be needed in final version. 
    if (kDebugMode && shot.typeShot == TypeShot.eoc) {
      debugPrint("DataProcessingService: EOC shot detected, cursor at $cursor");
      if (cursor + 20 < transferBuffer.length) {
        debugPrint("DataProcessingService: Next 20 bytes after type: ${transferBuffer.sublist(cursor, cursor + 20)}");
      }
    }

    // For EOC shots, only skip the 9 zero bytes and don't read shot fields
    if (shot.typeShot == TypeShot.eoc) {
      cursor += 9; // Skip the 9 zero bytes in EOC data
      if (kDebugMode) {
        debugPrint("DataProcessingService: EOC shot - skipped 9 zero bytes, cursor at $cursor");
      }

      // Some V6 files incorrectly have Lidar data after EOC shots - skip it
      if (fileVersion >= 6) {
        if (cursor + 2 < transferBuffer.length &&
            transferBuffer[cursor] == _lidarStartValueA &&
            transferBuffer[cursor + 1] == _lidarStartValueB &&
            transferBuffer[cursor + 2] == _lidarStartValueC) {
          if (kDebugMode) {
            debugPrint("DataProcessingService: Skipping invalid Lidar data after EOC shot at position $cursor");
          }
          cursor += 3; // Skip Lidar magic bytes

          if (cursor + 1 < transferBuffer.length) {
            final lidarLength = _readIntFromBuffer(transferBuffer, cursor);
            cursor += 2;
            cursor += lidarLength; // Skip Lidar data

            if (kDebugMode) {
              debugPrint("DataProcessingService: Skipped $lidarLength bytes of Lidar data, cursor now at $cursor");
            }
          }
        }
      }

      return _ShotProcessingResult(shot, cursor, false);
    }

    // Read shot data (need at least 16 bytes for basic shot data)
    if (cursor + 15 >= transferBuffer.length) {
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }

    shot.headingIn = _readIntFromBuffer(transferBuffer, cursor) / 10.0;
    cursor += 2;

    shot.headingOut = _readIntFromBuffer(transferBuffer, cursor) / 10.0;
    cursor += 2;

    shot.length = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;

    shot.depthIn = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;

    shot.depthOut = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;

    shot.pitchIn = _readIntFromBuffer(transferBuffer, cursor) / 10.0;
    cursor += 2;

    shot.pitchOut = _readIntFromBuffer(transferBuffer, cursor) / 10.0;
    cursor += 2;

    if (kDebugMode) {
      debugPrint("DataProcessingService: Shot type=$typeShot, "
          "heading=${shot.headingIn}/${shot.headingOut}, "
          "length=${shot.length}, "
          "depth=${shot.depthIn}/${shot.depthOut}, "
          "pitch=${shot.pitchIn}/${shot.pitchOut}");
    }


    // Read LRUD data for version 4+
    if (fileVersion >= 4) {
      if (cursor + 7 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      shot.left = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
      shot.right = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
      shot.up = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
      shot.down = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;

      if (kDebugMode) {
        debugPrint("DataProcessingService: LRUD: ${shot.left} ${shot.right} ${shot.up} ${shot.down}");
      }
    }

    // Read temperature and time for version 3+
    if (fileVersion >= 3) {
      if (cursor + 4 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      shot.temperature = _readIntFromBuffer(transferBuffer, cursor) / 10.0;
      cursor += 2;

      shot.hr = _readByteFromBuffer(transferBuffer, cursor++);
      shot.min = _readByteFromBuffer(transferBuffer, cursor++);
      shot.sec = _readByteFromBuffer(transferBuffer, cursor++);

      if (kDebugMode) {
        debugPrint("DataProcessingService: Temperature=${shot.temperature}, "
            "Time=${shot.hr}:${shot.min}:${shot.sec}");
      }
    }

    // Read marker index
    if (cursor >= transferBuffer.length) {
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }

    shot.markerIndex = _readByteFromBuffer(transferBuffer, cursor++);

    // Validate shot end magic bytes for version 5+
    if (fileVersion >= 5) {
      if (cursor + 2 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      final checkByteA = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteB = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteC = _readByteFromBuffer(transferBuffer, cursor++);

      if (checkByteA != _shotEndValueA ||
          checkByteB != _shotEndValueB ||
          checkByteC != _shotEndValueC) {
        if (kDebugMode) {
          debugPrint("DataProcessingService: Invalid shot end magic bytes");
                  }
        return _ShotProcessingResult(shot, cursor - 3, true);
      }
    }

    // Process optional Lidar data for V6 format (but not for EOC shots)
    if (fileVersion >= 6 && shot.typeShot != TypeShot.eoc) {
      final lidarResult = await _processLidarData(transferBuffer, cursor, conversionFactor);
      shot.lidarData = lidarResult.lidarData;
      cursor = lidarResult.newCursor;

      if (lidarResult.brokenSegment) {
        return _ShotProcessingResult(shot, cursor, true);
      }
    }

    return _ShotProcessingResult(shot, cursor, false);
  }

  /// Read a single byte from the buffer
  int _readByteFromBuffer(List<int> buffer, int address) {
    return address < buffer.length ? buffer[address] : 0;
  }

  /// Read a 16-bit integer from the buffer (little endian)
  int _readIntFromBuffer(List<int> buffer, int address) {
    if (address + 1 >= buffer.length) return 0;

    final bytes = Uint8List.fromList([buffer[address], buffer[address + 1]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getInt16(0);
  }

  /// Read a 16-bit integer from the buffer (inverted endian)
  int _readInvIntFromBuffer(List<int> buffer, int address) {
    if (address + 1 >= buffer.length) return 0;

    final bytes = Uint8List.fromList([buffer[address + 1], buffer[address]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getInt16(0);
  }

  int _readUInt16FromBuffer(List<int> buffer, int address) {
    if (address + 1 >= buffer.length) return 0;

    // notice the order of the bytes is reversed for uint16
    final bytes = Uint8List.fromList([buffer[address + 1 ], buffer[address]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getUint16(0);
  }


  /// Process optional Lidar data from V6 format
  Future<_LidarProcessingResult> _processLidarData(
    List<int> transferBuffer,
    int startCursor,
    double conversionFactor,
  ) async {
    int cursor = startCursor;

    // Check if there's enough space for Lidar header (3 magic bytes + 2 length bytes)
    if (cursor + 4 >= transferBuffer.length) {
      if (kDebugMode) {
        debugPrint("DataProcessingService: No space for Lidar header, skipping");
      }
      return _LidarProcessingResult(null, cursor, false);
    }

    // Check for Lidar start magic bytes
    final checkByteA = _readByteFromBuffer(transferBuffer, cursor);
    final checkByteB = _readByteFromBuffer(transferBuffer, cursor + 1);
    final checkByteC = _readByteFromBuffer(transferBuffer, cursor + 2);

    if (checkByteA != _lidarStartValueA ||
        checkByteB != _lidarStartValueB ||
        checkByteC != _lidarStartValueC) {
      if (kDebugMode) {
        debugPrint("DataProcessingService: No Lidar magic bytes found, skipping");
      }
      return _LidarProcessingResult(null, cursor, false);
    }

    cursor += 3; // Skip magic bytes

    // Read data length
    final dataLength = _readIntFromBuffer(transferBuffer, cursor);
    cursor += 2;

    // Validate data length and buffer space
    if (dataLength == 0 || cursor + dataLength > transferBuffer.length) {
      if (kDebugMode) {
        debugPrint("DataProcessingService: Invalid Lidar data length or insufficient buffer");
      }
      return _LidarProcessingResult(null, cursor, true);
    }

    // Each Lidar point is 6 bytes (2 bytes each for YAW, PITCH, DISTANCE)
    if (dataLength % 6 != 0) {
      if (kDebugMode) {
        debugPrint("DataProcessingService: Invalid Lidar data length (not divisible by 6)");
      }
      return _LidarProcessingResult(null, cursor + dataLength, true);
    }

    final pointCount = dataLength ~/ 6;
    final lidarPoints = <LidarPoint>[];

    // Track statistics for debug output
    double minYaw = 0, maxYaw = 0;
    double minPitch = 0, maxPitch = 0;
    double minDistance = 0, maxDistance = 0;
    bool firstPoint = true;

    // Read each Lidar point
    for (int i = 0; i < pointCount; i++) {

      final yaw = _readUInt16FromBuffer(transferBuffer, cursor) / 100.0;
      cursor += 2;

      final pitch = _readInvIntFromBuffer(transferBuffer, cursor) / 100.0;
      cursor += 2;

      final distance = _readUInt16FromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;

      // Update statistics
      if (kDebugMode) {

        if (firstPoint) {
          minYaw = maxYaw = yaw;
          minPitch = maxPitch = pitch;
          minDistance = maxDistance = distance;
          firstPoint = false;
        } else {
          if (yaw < minYaw) minYaw = yaw;
          if (yaw > maxYaw) maxYaw = yaw;
          if (pitch < minPitch) minPitch = pitch;
          if (pitch > maxPitch) maxPitch = pitch;
          if (distance < minDistance) minDistance = distance;
          if (distance > maxDistance) maxDistance = distance;
        }
      }

      lidarPoints.add(LidarPoint(
        yaw: yaw,
        pitch: pitch,
        distance: distance,
      ));
    }

    final lidarData = LidarData(points: lidarPoints);

    if (kDebugMode && lidarPoints.isNotEmpty) {
      // Normalize angle ranges for better representation
      final (normalizedMinYaw, normalizedMaxYaw) = _normalizeAngleRange(minYaw, maxYaw);
      final (normalizedMinPitch, normalizedMaxPitch) = _normalizeAngleRange(minPitch, maxPitch);
      
      debugPrint("DataProcessingService: Lidar shot statistics - ${lidarPoints.length} points: "
          "Yaw(${normalizedMinYaw.toStringAsFixed(1)}° - ${normalizedMaxYaw.toStringAsFixed(1)}°), "
          "Pitch(${normalizedMinPitch.toStringAsFixed(1)}° - ${normalizedMaxPitch.toStringAsFixed(1)}°), "
          "Distance(${minDistance}m-${maxDistance}m)");
    }

    return _LidarProcessingResult(lidarData, cursor, false);
  }

  /// Normalize angle range to show the most logical representation
  /// For example: -5° to +5° instead of 355° to 5°
  /// Returns a tuple of (minAngle, maxAngle) in degrees, always with min <= max
  (double, double) _normalizeAngleRange(double minAngleDegrees, double maxAngleDegrees) {
    // Normalize angles to 0-360 range
    double normalizedMin = minAngleDegrees % 360.0;
    double normalizedMax = maxAngleDegrees % 360.0;

    if (normalizedMin < 0) normalizedMin += 360.0;
    if (normalizedMax < 0) normalizedMax += 360.0;

    // Calculate direct span (clockwise from min to max)
    final double directSpan = normalizedMax >= normalizedMin ?
        normalizedMax - normalizedMin :
        normalizedMin - normalizedMax + 360.0;

    // If direct span is <= 180°, use it; otherwise use boundary-crossing representation
    if (directSpan <= 180.0) {
      return normalizedMin <= normalizedMax ?
          (normalizedMin, normalizedMax) :
          (normalizedMax, normalizedMin);
    } else {
      // Use boundary-crossing representation (shorter path across 0°)
      return normalizedMax >= normalizedMin ?
          (normalizedMin, normalizedMax - 360.0) :
          (normalizedMin - 360.0, normalizedMax);
    }
  }

}

/// Result of data processing operation
class DataProcessingResult {
  final bool success;
  final List<Section> sections;
  final bool brokenSegmentDetected;
  final String? error;

  const DataProcessingResult._(
    this.success,
    this.sections,
    this.brokenSegmentDetected,
    this.error,
  );

  factory DataProcessingResult.success(
    List<Section> sections, {
    bool brokenSegmentDetected = false,
  }) =>
      DataProcessingResult._(true, sections, brokenSegmentDetected, null);

  factory DataProcessingResult.error(String error) =>
      DataProcessingResult._(false, <Section>[], false, error);

  bool get hasData => sections.isNotEmpty;
}

/// Internal result for section processing
class _SectionProcessingResult {
  final Section? section;
  final int newCursor;
  final bool brokenSegment;
  final bool shouldStop;

  _SectionProcessingResult(this.section, this.newCursor, this.brokenSegment, this.shouldStop);
}

/// Internal result for shot processing
class _ShotProcessingResult {
  final Shot shot;
  final int newCursor;
  final bool brokenSegment;

  _ShotProcessingResult(this.shot, this.newCursor, this.brokenSegment);
}

/// Internal result for Lidar data processing
class _LidarProcessingResult {
  final LidarData? lidarData;
  final int newCursor;
  final bool brokenSegment;

  _LidarProcessingResult(this.lidarData, this.newCursor, this.brokenSegment);
}