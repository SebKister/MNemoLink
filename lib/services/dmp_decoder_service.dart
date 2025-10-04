import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Memory pool for efficient buffer reuse
class _BufferPool {
  final Queue<List<int>> _pool = Queue();
  static const int _maxPoolSize = 5;
  static const int _maxBufferSize = 50000; // Don't pool huge buffers

  List<int> acquire() {
    if (_pool.isNotEmpty) {
      final buffer = _pool.removeFirst();
      buffer.clear();
      return buffer;
    }
    return <int>[];
  }

  void release(List<int> buffer) {
    if (_pool.length < _maxPoolSize && buffer.length < _maxBufferSize) {
      _pool.add(buffer);
    }
  }
}

/// Service for decoding DMP files (CSV to buffer to Section objects)
class DmpDecoderService {
  static final _BufferPool _bufferPool = _BufferPool();

  // ============================================================================
  // FILE-LEVEL OPERATIONS (CSV → Buffer)
  // ============================================================================

  /// Open and parse DMP file(s) - supports both single and multiple selection
  Future<MultiFileResult> openDMPFiles() async {
    try {
      FilePickerResult? result;

      if (Platform.isAndroid || Platform.isIOS) {
        result = await FilePicker.platform.pickFiles(
          dialogTitle: "Open DMP File(s)",
          type: FileType.any,
          allowMultiple: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          dialogTitle: "Open DMP File(s) - Hold Ctrl/Cmd or Shift for multiple",
          type: FileType.custom,
          allowedExtensions: ["dmp"],
          allowMultiple: true,
        );
      }

      if (result == null) {
        return MultiFileResult.cancelled();
      }

      final fileResults = <FileProcessingResult>[];

      for (int i = 0; i < result.files.length; i++) {
        final platformFile = result.files[i];

        if (platformFile.path == null) {
          continue;
        }

        try {
          final file = File(platformFile.path!);

          // Early validation pipeline
          final validationResult = await _validateDMPFile(file);
          if (!validationResult.isValid) {
            fileResults.add(FileProcessingResult.error(
              fileName: platformFile.name,
              error: validationResult.error!,
            ));
            continue;
          }

          final transferBuffer = await parseDMPFileOptimized(
            file,
            onProgress: (progress) {
              // Progress reporting could be exposed here if needed
            },
          );

          fileResults.add(FileProcessingResult.success(
            fileName: platformFile.name,
            data: transferBuffer,
          ));
        } catch (e) {
          fileResults.add(FileProcessingResult.error(
            fileName: platformFile.name,
            error: "Failed to parse: $e",
          ));
        }
      }

      return MultiFileResult.success(fileResults);

    } catch (e) {
      return MultiFileResult.error("Failed to open DMP files: $e");
    }
  }

  /// Early validation pipeline for DMP files
  Future<_ValidationResult> _validateDMPFile(File file) async {
    try {
      if (!await file.exists()) {
        return _ValidationResult.invalid("File does not exist");
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return _ValidationResult.invalid("File is empty (0 bytes)");
      }

      if (fileSize < 48) {
        return _ValidationResult.invalid(
          "File too small ($fileSize bytes) - minimum 48 bytes required for valid DMP format"
        );
      }

      // Quick format validation - read first line to check file version
      final firstBytes = await file.openRead(0, math.min(200, fileSize)).toList();
      final firstChunk = utf8.decode(firstBytes.expand((x) => x).toList());
      final firstLineEnd = firstChunk.indexOf('\n');
      final firstLine = firstLineEnd > 0 ? firstChunk.substring(0, firstLineEnd) : firstChunk;
      final fields = firstLine.split(';');

      if (fields.isEmpty) {
        return _ValidationResult.invalid("Invalid CSV format - no fields found");
      }

      final version = _parseElementOptimized(fields.first);
      if (version == null || !DmpConstants.isValidVersion(version)) {
        return _ValidationResult.invalid(
          "Invalid DMP file version: ${fields.first}. Supported versions: ${DmpConstants.minSupportedVersion}-${DmpConstants.maxSupportedVersion}"
        );
      }

      return _ValidationResult.valid();
    } catch (e) {
      return _ValidationResult.invalid("Validation failed: $e");
    }
  }

  /// Optimized integer parsing with early type checking
  int? _parseElementOptimized(dynamic element) {
    if (element == null || element == "") return null;

    // Fast path for integers
    if (element is int) return element;

    // Optimized string parsing
    if (element is String) {
      if (element.isEmpty) return null;
      return int.tryParse(element);
    }

    // Fallback for other types
    return int.tryParse(element.toString());
  }

  /// Stream-based DMP file parsing with batching and progress reporting
  Future<List<int>> parseDMPFileOptimized(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    const batchSize = 1000;
    final fileSize = await file.length();
    int processedBytes = 0;

    final transferBuffer = _bufferPool.acquire();

    try {
      final stream = file.openRead()
          .transform(utf8.decoder)
          .transform(LineSplitter());

      await for (final line in stream) {
        processedBytes += line.length + 1; // +1 for newline

        // Parse CSV line
        final fields = line.split(';');
        if (fields.isEmpty) continue;

        // Process in batches to avoid blocking UI
        for (int start = 0; start < fields.length; start += batchSize) {
          final end = math.min(start + batchSize, fields.length);

          for (int i = start; i < end; i++) {
            final value = _parseElementOptimized(fields[i]);
            if (value != null) {
              transferBuffer.add(value);
            }
          }

          // Yield control back to UI thread after each batch
          if (end - start >= batchSize) {
            await Future.delayed(Duration.zero);
          }
        }

        // Report progress
        onProgress?.call(processedBytes / fileSize);

        // Only process first line for DMP files (they're single-line CSV)
        break;
      }

      if (transferBuffer.isEmpty) {
        throw Exception("No valid numeric data found in DMP file");
      }

      // Create a copy since we're returning from the pool
      final result = List<int>.from(transferBuffer);
      return result;

    } catch (e) {
      rethrow;
    } finally {
      _bufferPool.release(transferBuffer);
    }
  }

  // ============================================================================
  // BUFFER-LEVEL OPERATIONS (Buffer → Section Objects)
  // ============================================================================

  /// Process raw binary transfer buffer into survey sections
  Future<DataProcessingResult> processTransferBuffer(
    List<int> transferBuffer,
    UnitType unitType
  ) async {
    try {
      if (transferBuffer.isEmpty) {
        return DataProcessingResult.error("Transfer buffer is empty");
      }

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

        // Safety check to prevent infinite loops
        if (cursor <= 0 || cursor >= transferBuffer.length) {
          break;
        }
      }

      return DataProcessingResult.success(
        sections,
        brokenSegmentDetected: brokenSegmentDetected
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("DmpDecoderService: Error processing transfer buffer: $e");
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
      debugPrint("DmpDecoderService: Starting new section at cursor $cursor");
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
    if (DmpConstants.usesMagicBytes(fileVersion)) {
      if (cursor + 2 >= transferBuffer.length) {
        return _SectionProcessingResult(null, cursor, false, true);
      }

      final checkByteA = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteB = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteC = _readByteFromBuffer(transferBuffer, cursor++);

      if (checkByteA != DmpConstants.fileVersionMagicA ||
          checkByteB != DmpConstants.fileVersionMagicB ||
          checkByteC != DmpConstants.fileVersionMagicC) {
        if (kDebugMode) {
          debugPrint("DmpDecoderService: Invalid file version magic bytes");
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
        debugPrint("DmpDecoderService: Invalid direction index: $directionIndex");
      }
      return _SectionProcessingResult(null, cursor, false, true);
    }

    if (kDebugMode) {
      debugPrint("DmpDecoderService: Section ${section.name}, "
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
        debugPrint("DmpDecoderService: Completed section with ${section.shots.length} shots");
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
    if (DmpConstants.usesMagicBytes(fileVersion)) {
      if (cursor + 2 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      final checkByteA = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteB = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteC = _readByteFromBuffer(transferBuffer, cursor++);

      if (checkByteA != DmpConstants.shotStartMagicA ||
          checkByteB != DmpConstants.shotStartMagicB ||
          checkByteC != DmpConstants.shotStartMagicC) {
        if (kDebugMode) {
          debugPrint("DmpDecoderService: Invalid shot start magic bytes");
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
        debugPrint("DmpDecoderService: Invalid shot type: $typeShot");
      }
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }

    shot.typeShot = TypeShot.values[typeShot];

    // For EOC shots, only skip the 9 zero bytes and don't read shot fields
    if (shot.typeShot == TypeShot.eoc) {
      cursor += 9; // Skip the 9 zero bytes in EOC data

      // Some V6 files incorrectly have Lidar data after EOC shots - skip it
      if (DmpConstants.hasLidar(fileVersion)) {
        if (cursor + 2 < transferBuffer.length &&
            transferBuffer[cursor] == DmpConstants.lidarStartMagicA &&
            transferBuffer[cursor + 1] == DmpConstants.lidarStartMagicB &&
            transferBuffer[cursor + 2] == DmpConstants.lidarStartMagicC) {
          if (kDebugMode) {
            debugPrint("DmpDecoderService: Skipping invalid Lidar data after EOC shot");
          }
          cursor += 3; // Skip Lidar magic bytes

          if (cursor + 1 < transferBuffer.length) {
            final lidarLength = _readInt16(transferBuffer, cursor);
            cursor += 2;
            cursor += lidarLength; // Skip Lidar data
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

    shot.headingIn = _readInt16(transferBuffer, cursor) / 10.0;
    cursor += 2;

    shot.headingOut = _readInt16(transferBuffer, cursor) / 10.0;
    cursor += 2;

    shot.length = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;

    shot.depthIn = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;

    shot.depthOut = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
    cursor += 2;

    shot.pitchIn = _readInt16(transferBuffer, cursor) / 10.0;
    cursor += 2;

    shot.pitchOut = _readInt16(transferBuffer, cursor) / 10.0;
    cursor += 2;

    // Read LRUD data for version 4+
    if (DmpConstants.hasLRUD(fileVersion)) {
      if (cursor + 7 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      shot.left = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
      shot.right = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
      shot.up = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
      shot.down = _readInt16(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;
    }

    // Read temperature and time for version 3+
    if (DmpConstants.hasTemperature(fileVersion)) {
      if (cursor + 4 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      shot.temperature = _readInt16(transferBuffer, cursor) / 10.0;
      cursor += 2;

      shot.hr = _readByteFromBuffer(transferBuffer, cursor++);
      shot.min = _readByteFromBuffer(transferBuffer, cursor++);
      shot.sec = _readByteFromBuffer(transferBuffer, cursor++);
    }

    // Read marker index
    if (cursor >= transferBuffer.length) {
      shot.typeShot = TypeShot.eoc;
      return _ShotProcessingResult(shot, cursor, true);
    }

    shot.markerIndex = _readByteFromBuffer(transferBuffer, cursor++);

    // Validate shot end magic bytes for version 5+
    if (DmpConstants.usesMagicBytes(fileVersion)) {
      if (cursor + 2 >= transferBuffer.length) {
        shot.typeShot = TypeShot.eoc;
        return _ShotProcessingResult(shot, cursor, true);
      }

      final checkByteA = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteB = _readByteFromBuffer(transferBuffer, cursor++);
      final checkByteC = _readByteFromBuffer(transferBuffer, cursor++);

      if (checkByteA != DmpConstants.shotEndMagicA ||
          checkByteB != DmpConstants.shotEndMagicB ||
          checkByteC != DmpConstants.shotEndMagicC) {
        if (kDebugMode) {
          debugPrint("DmpDecoderService: Invalid shot end magic bytes");
        }
        return _ShotProcessingResult(shot, cursor - 3, true);
      }
    }

    // Process optional Lidar data for V6 format (but not for EOC shots)
    if (DmpConstants.hasLidar(fileVersion) && shot.typeShot != TypeShot.eoc) {
      final lidarResult = await _processLidarData(transferBuffer, cursor, conversionFactor);
      shot.lidarData = lidarResult.lidarData;
      cursor = lidarResult.newCursor;

      if (lidarResult.brokenSegment) {
        return _ShotProcessingResult(shot, cursor, true);
      }
    }

    return _ShotProcessingResult(shot, cursor, false);
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
      return _LidarProcessingResult(null, cursor, false);
    }

    // Check for Lidar start magic bytes
    final checkByteA = _readByteFromBuffer(transferBuffer, cursor);
    final checkByteB = _readByteFromBuffer(transferBuffer, cursor + 1);
    final checkByteC = _readByteFromBuffer(transferBuffer, cursor + 2);

    if (checkByteA != DmpConstants.lidarStartMagicA ||
        checkByteB != DmpConstants.lidarStartMagicB ||
        checkByteC != DmpConstants.lidarStartMagicC) {
      return _LidarProcessingResult(null, cursor, false);
    }

    cursor += 3; // Skip magic bytes

    // Read data length
    final dataLength = _readInt16(transferBuffer, cursor);
    cursor += 2;

    // Validate data length and buffer space
    if (dataLength == 0 || cursor + dataLength > transferBuffer.length) {
      if (kDebugMode) {
        debugPrint("DmpDecoderService: Invalid Lidar data length or insufficient buffer");
      }
      return _LidarProcessingResult(null, cursor, true);
    }

    // Each Lidar point is 6 bytes (2 bytes each for YAW, PITCH, DISTANCE)
    if (dataLength % 6 != 0) {
      if (kDebugMode) {
        debugPrint("DmpDecoderService: Invalid Lidar data length (not divisible by 6)");
      }
      return _LidarProcessingResult(null, cursor + dataLength, true);
    }

    final pointCount = dataLength ~/ 6;
    final lidarPoints = <LidarPoint>[];

    // Read each Lidar point (big-endian for Lidar data)
    for (int i = 0; i < pointCount; i++) {
      final yaw = _readUInt16Inverted(transferBuffer, cursor) / 100.0;
      cursor += 2;

      final pitch = _readInt16Inverted(transferBuffer, cursor) / 100.0;
      cursor += 2;

      final distance = _readUInt16Inverted(transferBuffer, cursor) * conversionFactor / 100.0;
      cursor += 2;

      lidarPoints.add(LidarPoint(
        yaw: yaw,
        pitch: pitch,
        distance: distance,
      ));
    }

    final lidarData = LidarData(points: lidarPoints);

    return _LidarProcessingResult(lidarData, cursor, false);
  }

  // ============================================================================
  // BUFFER READING HELPERS
  // ============================================================================

  /// Read a single byte from the buffer
  int _readByteFromBuffer(List<int> buffer, int address) {
    if (address < 0 || address >= buffer.length) {
      return 0;
    }
    return buffer[address];
  }

  /// Read a 16-bit signed integer from the buffer (LSB; MSB - default format)
  int _readInt16(List<int> buffer, int address) {
    if (address + 1 >= buffer.length) return 0;

    final bytes = Uint8List.fromList([buffer[address], buffer[address + 1]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getInt16(0, Endian.big);
  }

  /// Read a 16-bit unsigned integer from buffer (MSB; LSB - for Lidar data)
  int _readUInt16Inverted(List<int> buffer, int address) {
    if (address + 1 >= buffer.length) return 0;

    final bytes = Uint8List.fromList([buffer[address + 1], buffer[address]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getUint16(0, Endian.big);
  }

  /// Read a 16-bit signed integer from buffer (MSB; LSB - for Lidar data)
  int _readInt16Inverted(List<int> buffer, int address) {
    if (address + 1 >= buffer.length) return 0;

    final bytes = Uint8List.fromList([buffer[address + 1], buffer[address]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getInt16(0, Endian.big);
  }
}

// ============================================================================
// RESULT CLASSES
// ============================================================================

/// Result of data processing operation (buffer → sections)
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

/// Result of processing multiple files
class MultiFileResult {
  final bool success;
  final List<FileProcessingResult>? results;
  final String? error;

  const MultiFileResult._(this.success, this.results, this.error);

  factory MultiFileResult.success(List<FileProcessingResult> results) =>
      MultiFileResult._(true, results, null);

  factory MultiFileResult.error(String error) =>
      MultiFileResult._(false, null, error);

  factory MultiFileResult.cancelled() =>
      MultiFileResult._(false, null, "Operation cancelled");

  bool get hasResults => results != null && results!.isNotEmpty;
  bool get isCancelled => !success && error == "Operation cancelled";

  List<FileProcessingResult> get successfulFiles =>
      results?.where((r) => r.success).toList() ?? [];

  List<FileProcessingResult> get failedFiles =>
      results?.where((r) => !r.success).toList() ?? [];
}

/// Result of processing a single file within a multi-file operation
class FileProcessingResult {
  final bool success;
  final String fileName;
  final List<int>? data;
  final String? error;

  const FileProcessingResult._(this.success, this.fileName, this.data, this.error);

  factory FileProcessingResult.success({
    required String fileName,
    required List<int> data,
  }) => FileProcessingResult._(true, fileName, data, null);

  factory FileProcessingResult.error({
    required String fileName,
    required String error,
  }) => FileProcessingResult._(false, fileName, null, error);

  bool get hasData => data != null && data!.isNotEmpty;
}

/// Result of early file validation
class _ValidationResult {
  final bool isValid;
  final String? error;

  const _ValidationResult._(this.isValid, this.error);

  factory _ValidationResult.valid() => const _ValidationResult._(true, null);
  factory _ValidationResult.invalid(String error) => _ValidationResult._(false, error);
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
