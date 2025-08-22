import 'dart:convert';
import 'dart:math' as math;
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
  
  // Angle calculation constants
  static const double _pi = 3.14159265359;
  static const double _degreesToRadians = _pi / 180.0;
  static const double _minAngleRadians = 0.0175; // 1 degree in radians
  static const double _rawToDegreesConversion = 10.0; // Raw compass values to degrees

  /// Process raw binary transfer buffer into survey sections
  Future<DataProcessingResult> processTransferBuffer(
    List<int> transferBuffer, 
    UnitType unitType, {
    bool enableLineTensionValidation = false,
    double lineTensionThresholdRatio = 0.5,
    LineTensionAdjustmentMethod adjustmentMethod = LineTensionAdjustmentMethod.useDepthChange,
    double azimuthCorrectionStrength = 0.4,
  }) async {
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

      // Apply line tension validation and adjustment if enabled
      if (enableLineTensionValidation) {
        _processLineTensionValidation(
          sections,
          lineTensionThresholdRatio,
          adjustmentMethod,
          azimuthCorrectionStrength,
        );
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
    while (fileVersion != 2 && fileVersion != 3 && fileVersion != 4 && fileVersion != 5) {
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

    if (kDebugMode) {
      debugPrint("DataProcessingService: Processing shot at cursor $cursor");
    }

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

    // Read shot data (need at least 16 bytes for basic shot data)
    if (cursor + 15 >= transferBuffer.length) {
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }

    shot.headingIn = _readIntFromBuffer(transferBuffer, cursor);
    cursor += 2;
    
    shot.headingOut = _readIntFromBuffer(transferBuffer, cursor);
    cursor += 2;
    
    shot.length = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;
    
    shot.depthIn = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;
    
    shot.depthOut = _readIntFromBuffer(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;
    
    shot.pitchIn = _readIntFromBuffer(transferBuffer, cursor);
    cursor += 2;
    
    shot.pitchOut = _readIntFromBuffer(transferBuffer, cursor);
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
      
      shot.temperature = _readIntFromBuffer(transferBuffer, cursor);
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

  /// Process line tension validation and adjustment for all sections
  void _processLineTensionValidation(
    List<Section> sections,
    double thresholdRatio,
    LineTensionAdjustmentMethod adjustmentMethod,
    double azimuthCorrectionStrength,
  ) {
    for (final section in sections) {
      _validateAndAdjustSectionShots(section, thresholdRatio, adjustmentMethod, azimuthCorrectionStrength);
    }
  }

  /// Validate and adjust shots in a single section for line tension issues
  void _validateAndAdjustSectionShots(
    Section section,
    double thresholdRatio,
    LineTensionAdjustmentMethod adjustmentMethod,
    double azimuthCorrectionStrength,
  ) {
    final shots = section.shots;
    
    for (int i = 0; i < shots.length; i++) {
      final shot = shots[i];
      
      // Skip non-standard shots (CSA, CSB, EOC)
      if (shot.typeShot != TypeShot.std) continue;
      
      final depthChange = shot.getDepthChange();
      
      // Check if shot is invalid:
      // 1. Distance shorter than depth change is always invalid (physically impossible)
      // 2. Distance only slightly longer than depth change may also be invalid (controlled by threshold)
      final isPhysicallyImpossible = shot.length < depthChange;
      final isSuspiciouslyShort = depthChange > 0 && 
          shot.length < (depthChange * (1.0 + thresholdRatio));
      
      if (isPhysicallyImpossible || isSuspiciouslyShort) {
        // Mark as invalid and store original length
        shot.setIsLineTensionInvalid(true);
        shot.setOriginalLength(shot.length);
        
        // Adjust the distance based on selected method
        switch (adjustmentMethod) {
          case LineTensionAdjustmentMethod.useDepthChange:
            shot.setLength(depthChange);
            break;
          case LineTensionAdjustmentMethod.useAverageAngle:
            final adjustedDistance = _calculateDistanceFromAverageAngle(shots, i, azimuthCorrectionStrength);
            if (adjustedDistance > 0) {
              shot.setLength(adjustedDistance);
            } else {
              // Fallback to depth change if angle calculation fails
              shot.setLength(depthChange);
            }
            break;
        }
        
        if (kDebugMode) {
          final reason = isPhysicallyImpossible ? "physically impossible" : "suspiciously short";
          debugPrint("Line tension adjustment: Shot $i in section ${section.name} "
              "($reason) adjusted from ${shot.originalLength.toStringAsFixed(2)} to "
              "${shot.length.toStringAsFixed(2)} (depth change: ${depthChange.toStringAsFixed(2)})");
        }
      }
    }
  }

  /// Calculate distance using average angle from adjacent shots
  double _calculateDistanceFromAverageAngle(List<Shot> shots, int currentIndex, double azimuthCorrectionStrength) {
    final currentShot = shots[currentIndex];
    final depthChange = currentShot.getDepthChange();
    
    if (kDebugMode) {
      debugPrint("Line tension adjustment [Shot $currentIndex]: orig=${currentShot.length.toStringAsFixed(2)}, depth_change=${depthChange.toStringAsFixed(2)}");
    }
    
    // Find valid adjacent shots for angle calculation
    Shot? prevShot;
    Shot? nextShot;
    
    // Look for previous valid shot
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (shots[i].typeShot == TypeShot.std && !shots[i].isLineTensionInvalid) {
        prevShot = shots[i];
        break;
      }
    }
    
    // Look for next valid shot
    for (int i = currentIndex + 1; i < shots.length; i++) {
      if (shots[i].typeShot == TypeShot.std && !shots[i].isLineTensionInvalid) {
        nextShot = shots[i];
        break;
      }
    }
    
    // Need at least one adjacent shot for angle calculation
    if (prevShot == null && nextShot == null) {
      if (kDebugMode) {
        debugPrint("  No adjacent shots found, using fallback");
      }
      return 0.0; // Cannot calculate, fallback will be used
    }
    
    // Calculate average depth angle from adjacent shots' geometry
    double totalPitch = 0.0;
    int shotCount = 0;
    
    if (prevShot != null) {
      // Calculate depth angle from the shot's geometry
      final prevDepthChange = prevShot.getDepthChange();
      final prevLength = prevShot.length;
      
      // Calculate depth angle: arcsin(depth_change / length)
      double depthAngleDegrees = 0.0;
      if (prevLength > 0 && prevDepthChange > 0) {
        final sinDepthAngle = prevDepthChange / prevLength;
        if (sinDepthAngle <= 1.0) { // Ensure valid sine value
          depthAngleDegrees = math.asin(sinDepthAngle) / _degreesToRadians;
        }
      }
      
      totalPitch += depthAngleDegrees;
      shotCount++;
      
      if (kDebugMode) {
        debugPrint("  Prev: ${depthAngleDegrees.toStringAsFixed(1)}° (${prevDepthChange.toStringAsFixed(2)}/${prevLength.toStringAsFixed(2)})");
      }
    }
    
    if (nextShot != null) {
      // Calculate depth angle from the shot's geometry
      final nextDepthChange = nextShot.getDepthChange();
      final nextLength = nextShot.length;
      
      // Calculate depth angle: arcsin(depth_change / length)
      double depthAngleDegrees = 0.0;
      if (nextLength > 0 && nextDepthChange > 0) {
        final sinDepthAngle = nextDepthChange / nextLength;
        if (sinDepthAngle <= 1.0) { // Ensure valid sine value
          depthAngleDegrees = math.asin(sinDepthAngle) / _degreesToRadians;
        }
      }
      
      totalPitch += depthAngleDegrees;
      shotCount++;
      
      if (kDebugMode) {
        debugPrint("  Next: ${depthAngleDegrees.toStringAsFixed(1)}° (${nextDepthChange.toStringAsFixed(2)}/${nextLength.toStringAsFixed(2)})");
      }
    }
    
    final averageDepthAngle = totalPitch / shotCount;
    
    // Convert depth angle to radians and calculate distance
    // Using the formula: distance = depth_change / sin(depth_angle)
    final depthAngleRadians = averageDepthAngle * _degreesToRadians;
    
    // Calculate distance using: depth_change = distance * sin(depth_angle)
    // Therefore: distance = depth_change / sin(depth_angle)
    if (depthAngleRadians.abs() < _minAngleRadians) { // Less than 1 degree, treat as horizontal
      if (kDebugMode) {
        debugPrint("  Avg angle: ${averageDepthAngle.toStringAsFixed(1)}° → horizontal, result: ${depthChange.toStringAsFixed(2)}");
      }
      return depthChange; // If nearly horizontal, use depth change as distance
    }
    
    final sinDepthAngle = math.sin(depthAngleRadians.abs());
    final baseDistance = depthChange / sinDepthAngle;
    
    // Factor in azimuth (direction) changes to account for lateral tape deviation
    final azimuthCorrection = _calculateAzimuthCorrection(shots, currentIndex, prevShot, nextShot, azimuthCorrectionStrength);
    final calculatedDistance = baseDistance * azimuthCorrection;
    
    if (kDebugMode) {
      debugPrint("  Avg angle: ${averageDepthAngle.toStringAsFixed(1)}° → base: ${baseDistance.toStringAsFixed(2)}, azimuth factor: ${azimuthCorrection.toStringAsFixed(3)} → final: ${calculatedDistance.toStringAsFixed(2)}");
    }
    
    // Sanity check: ensure calculated distance is reasonable
    if (calculatedDistance > 0 && calculatedDistance < depthChange * 10) {
      return calculatedDistance;
    }
    
    if (kDebugMode) {
      debugPrint("  Sanity check failed (${calculatedDistance.toStringAsFixed(2)}), using fallback");
    }
    
    return 0.0; // Invalid calculation, fallback will be used
  }

  /// Calculate azimuth correction factor based on direction changes
  double _calculateAzimuthCorrection(List<Shot> shots, int currentIndex, Shot? prevShot, Shot? nextShot, double correctionStrength) {
    final currentShot = shots[currentIndex];
    
    // Use heading out for consistency (direction at the end of the shot)
    final currentHeading = currentShot.headingOut / _rawToDegreesConversion; // Convert from raw to degrees
    
    double totalHeadingDiff = 0.0;
    int comparisonCount = 0;
    
    if (prevShot != null) {
      final prevHeading = prevShot.headingOut / _rawToDegreesConversion;
      final headingDiff = _calculateHeadingDifference(currentHeading, prevHeading);
      totalHeadingDiff += headingDiff;
      comparisonCount++;
      
      if (kDebugMode) {
        debugPrint("  Azimuth vs prev: ${currentHeading.toStringAsFixed(0)}° vs ${prevHeading.toStringAsFixed(0)}° = ${headingDiff.toStringAsFixed(1)}° diff");
      }
    }
    
    if (nextShot != null) {
      final nextHeading = nextShot.headingOut / _rawToDegreesConversion;
      final headingDiff = _calculateHeadingDifference(currentHeading, nextHeading);
      totalHeadingDiff += headingDiff;
      comparisonCount++;
      
      if (kDebugMode) {
        debugPrint("  Azimuth vs next: ${currentHeading.toStringAsFixed(0)}° vs ${nextHeading.toStringAsFixed(0)}° = ${headingDiff.toStringAsFixed(1)}° diff");
      }
    }
    
    if (comparisonCount == 0) {
      return 1.0; // No correction if no adjacent shots
    }
    
    final avgHeadingDiff = totalHeadingDiff / comparisonCount;
    
    // Calculate correction factor based on average heading difference
    // correctionStrength ranges from -0.99 to +0.99:
    // - Positive values: larger heading differences → longer distance (lengthening)
    // - Negative values: larger heading differences → shorter distance (shortening)
    // - Zero: no azimuth correction applied
    
    final normalizedDiff = avgHeadingDiff / 180.0; // 0.0 to 1.0
    final deviationFactor = 1.0 + (normalizedDiff * correctionStrength);
    
    if (kDebugMode) {
      debugPrint("  Avg heading diff: ${avgHeadingDiff.toStringAsFixed(1)}° → correction factor: ${deviationFactor.toStringAsFixed(3)} (strength: ${correctionStrength.toStringAsFixed(2)})");
    }
    
    return deviationFactor;
  }

  /// Calculate the smallest angle difference between two headings (accounting for 360° wrap)
  double _calculateHeadingDifference(double heading1, double heading2) {
    double diff = (heading1 - heading2).abs();
    if (diff > 180.0) {
      diff = 360.0 - diff;
    }
    return diff;
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