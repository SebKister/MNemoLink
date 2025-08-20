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