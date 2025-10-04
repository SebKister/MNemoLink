import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import '../excelexport.dart';
import '../survexporter.dart';
import '../thexporter.dart';
import 'dmp_decoder_service.dart';
import 'dmp_encoder_service.dart';

/// Service for handling file operations (import/export)
class FileService {
  final DmpDecoderService _dmpDecoder = DmpDecoderService();
  final DmpEncoderService _dmpEncoder = DmpEncoderService();
  
  /// Open and parse DMP file(s) - supports both single and multiple selection
  Future<MultiFileResult> openDMPFiles() async {
    return _dmpDecoder.openDMPFiles();
  }

  /// Parse a single DMP file
  Future<List<int>> parseDMPFile(File file) async {
    return _dmpDecoder.parseDMPFileOptimized(file);
  }

  /// Save data as DMP file (raw buffer)
  Future<FileResult> saveDMPFile(List<int> transferBuffer) async {
    try {
      final result = await _getSaveFilePath("DMP", "dmp");
      if (result == null) {
        return FileResult.cancelled();
      }

      final file = File(result);
      await _dmpEncoder.writeBufferToFile(transferBuffer, file);

      return FileResult.success(null, message: "DMP file saved successfully");

    } catch (e) {
      return FileResult.error("Failed to save DMP file: $e");
    }
  }

  /// Save selected sections as DMP file
  Future<FileResult> saveDMPFileFromSections(SectionList sections, UnitType unitType) async {
    try {
      final selectedSections = sections.selectedSections;

      if (selectedSections.isEmpty) {
        return FileResult.error("No sections selected");
      }

      // Analyze version distribution
      final analysis = _dmpEncoder.analyzeVersions(selectedSections);

      // If mixed versions, return special result for UI to handle
      if (analysis.isMixed) {
        return FileResult.needsUserChoice(analysis);
      }

      // All sections are same version - proceed with export
      final version = analysis.isAllV6 ? 6 : 5;

      final result = await _getSaveFilePath("DMP (Selected)", "dmp");
      if (result == null) {
        return FileResult.cancelled();
      }

      final buffer = _dmpEncoder.encodeSectionsToBuffer(selectedSections, version);
      final file = File(result);
      await _dmpEncoder.writeBufferToFile(buffer, file);

      return FileResult.success(null, message: "DMP file saved successfully (v$version format)");

    } catch (e) {
      return FileResult.error("Failed to save DMP file: $e");
    }
  }

  /// Save sections as separate v5 and v6 DMP files
  Future<FileResult> saveDMPFileSeparate(VersionAnalysis analysis, String basePath) async {
    try {
      // Remove .dmp extension if present
      final basePathWithoutExt = basePath.toLowerCase().endsWith('.dmp')
          ? basePath.substring(0, basePath.length - 4)
          : basePath;

      // Save v5 sections if any
      if (analysis.hasV5) {
        final v5Buffer = _dmpEncoder.encodeSectionsToBuffer(analysis.v5Sections, 5);
        final v5File = File('${basePathWithoutExt}_v5.dmp');
        await _dmpEncoder.writeBufferToFile(v5Buffer, v5File);
      }

      // Save v6 sections if any
      if (analysis.hasV6) {
        final v6Buffer = _dmpEncoder.encodeSectionsToBuffer(analysis.v6Sections, 6);
        final v6File = File('${basePathWithoutExt}_v6.dmp');
        await _dmpEncoder.writeBufferToFile(v6Buffer, v6File);
      }

      return FileResult.success(
        null,
        message: "Saved ${analysis.v5Count} v5 sections and ${analysis.v6Count} v6 sections in separate files"
      );

    } catch (e) {
      return FileResult.error("Failed to save separate DMP files: $e");
    }
  }

  /// Save all sections as v6 DMP file (converts v5 to v6 format)
  Future<FileResult> saveDMPFileAsV6(List<Section> sections, String filePath) async {
    try {
      final buffer = _dmpEncoder.encodeSectionsToBuffer(sections, 6);
      final file = File(filePath);
      await _dmpEncoder.writeBufferToFile(buffer, file);

      return FileResult.success(null, message: "DMP file saved successfully (all as v6 format)");

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

  /// Public method to get save file path (for external use)
  Future<String?> getSaveFilePathPublic(String dialogTitle, String extension) async {
    return _getSaveFilePath(dialogTitle, extension);
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
  final VersionAnalysis? versionAnalysis;
  final bool needsChoice;

  const FileResult._(
    this.success,
    this.data,
    this.message,
    this.error,
    this.versionAnalysis,
    this.needsChoice,
  );

  factory FileResult.success(List<int>? data, {String? message}) =>
      FileResult._(true, data, message, null, null, false);

  factory FileResult.error(String error) =>
      FileResult._(false, null, null, error, null, false);

  factory FileResult.cancelled() =>
      FileResult._(false, null, "Operation cancelled", null, null, false);

  factory FileResult.needsUserChoice(VersionAnalysis analysis) =>
      FileResult._(false, null, null, null, analysis, true);

  bool get hasData => data != null && data!.isNotEmpty;
  bool get isCancelled => !success && error == null && !needsChoice;
}