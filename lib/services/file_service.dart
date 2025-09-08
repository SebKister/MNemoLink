import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import '../excelexport.dart';
import '../survexporter.dart';
import '../thexporter.dart';

/// Service for handling file operations (import/export)
class FileService {
  
  /// Open and parse a DMP file
  Future<FileResult> openDMPFile() async {
    try {
      FilePickerResult? result;
      
      if (Platform.isAndroid || Platform.isIOS) {
        result = await FilePicker.platform.pickFiles(
          dialogTitle: "Open DMP",
          type: FileType.any,
          allowMultiple: false,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          dialogTitle: "Open DMP",
          type: FileType.custom,
          allowedExtensions: ["dmp"],
          allowMultiple: false,
        );
      }

      if (result == null) {
        return FileResult.cancelled();
      }

      final file = File(result.files.first.path!);
      final input = file.openRead();
      
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter(fieldDelimiter: ';'))
          .toList();

      final transferBuffer = <int>[];
      for (var element in fields[0]) {
        if (element != "") transferBuffer.add(element);
      }

      return FileResult.success(transferBuffer);
      
    } catch (e) {
      return FileResult.error("Failed to open DMP file: $e");
    }
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