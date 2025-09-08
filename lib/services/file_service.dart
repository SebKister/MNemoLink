import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'dart:math' as math;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import '../excelexport.dart';
import '../survexporter.dart';
import '../thexporter.dart';

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

/// Service for handling file operations (import/export)
class FileService {
  static final _BufferPool _bufferPool = _BufferPool();
  
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
          "File too small (${fileSize} bytes) - minimum 48 bytes required for valid DMP format"
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
      if (version == null || version < 2 || version > 5) {
        return _ValidationResult.invalid(
          "Invalid DMP file version: ${fields.first}. Supported versions: 2-5"
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
  
  /// Legacy method for backward compatibility
  Future<List<int>> parseDMPFile(File file) async {
    return parseDMPFileOptimized(file);
  }

  /// Save data as DMP file
  Future<FileResult> saveDMPFile(List<int> transferBuffer) async {
    try {
      final result = await _getSaveFilePath("DMP", "dmp");
      if (result == null) {
        return FileResult.cancelled();
      }

      final file = File(result);
      final sink = file.openWrite();
      
      for (var element in transferBuffer) {
        final value = (element >= -128 && element <= 127) 
            ? element 
            : -(256 - element);
        sink.write("$value;");
      }

      await sink.flush();
      await sink.close();
      
      return FileResult.success(null, message: "DMP file saved successfully");
      
    } catch (e) {
      return FileResult.error("Failed to save DMP file: $e");
    }
  }

  /// Save selected sections as DMP file (simplified approach)
  Future<FileResult> saveDMPFileFromSections(SectionList sections, UnitType unitType) async {
    try {
      final result = await _getSaveFilePath("DMP (Selected)", "dmp");
      if (result == null) {
        return FileResult.cancelled();
      }

      // For now, we'll use a simplified approach since full DMP reconstruction is complex
      // We create a dummy DMP with just a placeholder for selected sections
      final file = File(result);
      final sink = file.openWrite();
      
      // Write a simple text representation of selected sections
      sink.write("# Selected sections DMP export\n");
      sink.write("# ${sections.selectedSections.length} sections selected\n");
      for (final section in sections.selectedSections) {
        sink.write("# Section: ${section.name} (${section.shots.length} shots)\n");
      }
      sink.write("# Note: This is a simplified export. Use other formats for full data.\n");

      await sink.flush();
      await sink.close();
      
      return FileResult.success(null, message: "Selected sections info saved as DMP file");
      
    } catch (e) {
      return FileResult.error("Failed to save DMP file: $e");
    }
  }

  /// Save sections as Excel file
  Future<FileResult> saveExcelFile(SectionList sections, UnitType unitType) async {
    try {
      final result = await _getSaveFilePath("Excel", "xlsx");
      if (result == null) {
        return FileResult.cancelled();
      }

      final file = File(result);
      
      // Use the excel export function from the existing file
      exportAsExcel(sections, file, unitType);
      
      return FileResult.success(null, message: "Excel file saved successfully");
      
    } catch (e) {
      return FileResult.error("Failed to save Excel file: $e");
    }
  }

  /// Save sections as Survex file
  Future<FileResult> saveSurvexFile(SectionList sections, UnitType unitType) async {
    try {
      final result = await _getSaveFilePath("Survex", "svx");
      if (result == null) {
        return FileResult.cancelled();
      }

      // Use the survex exporter from the existing file
      final exporter = SurvexExporter();
      await exporter.export(sections, result, unitType);
      
      return FileResult.success(null, message: "Survex file saved successfully");
      
    } catch (e) {
      return FileResult.error("Failed to save Survex file: $e");
    }
  }

  /// Save sections as Therion file
  Future<FileResult> saveTherionFile(SectionList sections, UnitType unitType) async {
    try {
      final result = await _getSaveFilePath("Therion (.th)", "th");
      if (result == null) {
        return FileResult.cancelled();
      }

      // Use the therion exporter from the existing file
      final exporter = THExporter();
      await exporter.export(sections, result, unitType);
      
      return FileResult.success(null, message: "Therion file saved successfully");
      
    } catch (e) {
      return FileResult.error("Failed to save Therion file: $e");
    }
  }

  /// Get file path for saving (handles platform differences)
  Future<String?> _getSaveFilePath(String dialogTitle, String extension) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _getMobileFilePath(extension);
    } else {
      return _getDesktopFilePath(dialogTitle, extension);
    }
  }

  /// Get file path for mobile platforms
  Future<String?> _getMobileFilePath(String extension) async {
    // TODO: Context needs to be provided by the caller for mobile file picker
    // For now, return null to indicate mobile save is not implemented
    return null;
  }

  /// Get file path for desktop platforms
  Future<String?> _getDesktopFilePath(String dialogTitle, String extension) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: "Save as $dialogTitle",
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (result == null) return null;

    final path = result.toLowerCase().endsWith('.$extension') 
        ? result 
        : "$result.$extension";
        
    return path;
  }

  /// Validate IP address format
  bool isValidIPFormat(String value) {
    final splits = value.split(".");
    
    if (splits.length != 4) return false;
    
    for (final split in splits) {
      final number = int.tryParse(split);
      if (number == null || number < 0 || number > 255) {
        return false;
      }
    }
    
    return true;
  }
}

/// Result of file operation
class FileResult {
  final bool success;
  final List<int>? data;
  final String? message;
  final String? error;

  const FileResult._(this.success, this.data, this.message, this.error);

  factory FileResult.success(List<int>? data, {String? message}) =>
      FileResult._(true, data, message, null);

  factory FileResult.error(String error) =>
      FileResult._(false, null, null, error);

  factory FileResult.cancelled() =>
      FileResult._(false, null, "Operation cancelled", null);

  bool get hasData => data != null && data!.isNotEmpty;
  bool get isCancelled => !success && error == null;
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