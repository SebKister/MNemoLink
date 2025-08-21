import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:disks_desktop/disks_desktop.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'device_communication_service.dart';

/// Service for handling firmware and software updates
class FirmwareUpdateService {
  static const int _maxRetryFirmware = 10;
  static const String _firmwareApiUrl = "https://api.github.com/repos/SebKister/Mnemo-V2/releases/latest";
  static const String _softwareApiUrl = "https://api.github.com/repos/SebKister/MnemoLink/releases/latest";
  
  final Dio _dio;
  final DeviceCommunicationService _deviceService;

  FirmwareUpdateService(this._deviceService) : _dio = Dio();

  /// Check for latest firmware version
  Future<UpdateCheckResult> checkLatestFirmware() async {
    try {
      final tempDir = await getTemporaryDirectory();
      const fileName = 'mnemofirmware.json';
      
      await _dio.download(_firmwareApiUrl, "${tempDir.path}/$fileName");
      
      final file = File("${tempDir.path}/$fileName");
      final data = await file.readAsString();
      final json = Map<String, dynamic>.from(
        jsonDecode(data)
      );
      
      final version = (json['tag_name'] as String).substring(1); // Remove 'v'
      final downloadUrl = json['assets'][0]['browser_download_url'] as String;
      
      return UpdateCheckResult.firmware(version, downloadUrl);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error checking firmware updates: $e");
      }
      return UpdateCheckResult.error("Failed to check firmware updates: $e");
    }
  }

  /// Check for latest software version
  Future<UpdateCheckResult> checkLatestSoftware() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final downloadsDir = await getDownloadsDirectory();
      const fileName = 'mnemolink.json';
      
      await _dio.download(_softwareApiUrl, "${tempDir.path}/$fileName");
      
      final file = File("${tempDir.path}/$fileName");
      final data = await file.readAsString();
      final json = Map<String, dynamic>.from(
        jsonDecode(data)
      );
      
      final version = (json['tag_name'] as String).substring(1); // Remove 'v'
      
      // Select appropriate asset based on platform
      String downloadUrl;
      String assetFileName;
      
      if (Platform.isLinux) {
        downloadUrl = json['assets'][0]['browser_download_url'];
        assetFileName = json['assets'][0]['name'];
      } else if (Platform.isMacOS) {
        downloadUrl = json['assets'][1]['browser_download_url'];
        assetFileName = json['assets'][1]['name'];
      } else if (Platform.isWindows) {
        downloadUrl = json['assets'][2]['browser_download_url'];
        assetFileName = json['assets'][2]['name'];
      } else {
        return UpdateCheckResult.error("Unsupported platform for software updates");
      }
      
      final savePath = '${downloadsDir?.path}/$assetFileName';
      return UpdateCheckResult.software(version, downloadUrl, savePath);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error checking software updates: $e");
      }
      return UpdateCheckResult.error("Failed to check software updates: $e");
    }
  }

  /// Update device firmware
  Future<UpdateResult> updateFirmware(String downloadUrl) async {
    try {
      // Download firmware
      final tempDir = await getTemporaryDirectory();
      final firmwarePath = '${tempDir.path}/firmware.uf2';
      
      await _dio.download(downloadUrl, firmwarePath);
      
      // Put device in firmware update mode
      final bootModeResult = await _deviceService.enterFirmwareUpdateMode();
      if (!bootModeResult) {
        return UpdateResult.error("Failed to enter firmware update mode");
      }
      
      // Wait for RPI-RP2 disk to appear
      final repository = DisksRepository();
      Disk? disk;
      int retryCounter = 0;
      
      do {
        await Future.delayed(const Duration(seconds: 2));
        final disks = await repository.query;
        
        try {
          disk = disks.firstWhere((element) =>
              element.description.contains("RPI RP2") ||
              element.description.contains("RPI-RP2"));
        } catch (e) {
          disk = null;
        }
        
      } while ((disk?.mountpoints.isEmpty ?? true) && retryCounter++ < _maxRetryFirmware);
      
      if (retryCounter >= _maxRetryFirmware || disk == null) {
        return UpdateResult.error("RPI-RP2 disk not found or not mounted");
      }
      
      // Copy firmware to device
      final targetPath = Platform.isWindows 
          ? "${disk.mountpoints[0].path}firmware.uf2"
          : "${disk.mountpoints[0].path}/firmware.uf2";
          
      await File(firmwarePath).copy(targetPath);
      
      // Wait for device to reboot
      await Future.delayed(const Duration(seconds: 15));
      
      return UpdateResult.success("Firmware updated successfully");
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error updating firmware: $e");
      }
      return UpdateResult.error("Failed to update firmware: $e");
    }
  }

  /// Download software update
  Future<UpdateResult> downloadSoftwareUpdate(
    String downloadUrl, 
    String savePath,
    Function(double)? onProgress,
  ) async {
    try {
      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
      
      return UpdateResult.success("Software downloaded to $savePath");
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error downloading software: $e");
      }
      return UpdateResult.error("Failed to download software: $e");
    }
  }

  /// Parse version string to components
  List<int> parseVersion(String version) {
    final parts = version.split('.');
    return parts.map((part) {
      final plusIndex = part.indexOf('+');
      if (plusIndex != -1) {
        return int.parse(part.substring(0, plusIndex));
      }
      return int.parse(part);
    }).toList();
  }

  /// Compare two version strings
  bool isNewerVersion(String current, String latest) {
    final currentParts = parseVersion(current);
    final latestParts = parseVersion(latest);
    
    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    
    return false;
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}

/// Result of update check
class UpdateCheckResult {
  final UpdateType type;
  final String? version;
  final String? downloadUrl;
  final String? savePath;
  final String? error;

  const UpdateCheckResult._(this.type, this.version, this.downloadUrl, this.savePath, this.error);

  factory UpdateCheckResult.firmware(String version, String downloadUrl) =>
      UpdateCheckResult._(UpdateType.firmware, version, downloadUrl, null, null);

  factory UpdateCheckResult.software(String version, String downloadUrl, String savePath) =>
      UpdateCheckResult._(UpdateType.software, version, downloadUrl, savePath, null);

  factory UpdateCheckResult.error(String error) =>
      UpdateCheckResult._(UpdateType.error, null, null, null, error);

  bool get hasError => type == UpdateType.error;
  bool get isFirmware => type == UpdateType.firmware;
  bool get isSoftware => type == UpdateType.software;
}

enum UpdateType {
  firmware,
  software,
  error,
}

/// Result of update operation
class UpdateResult {
  final bool success;
  final String message;

  const UpdateResult._(this.success, this.message);

  factory UpdateResult.success(String message) => UpdateResult._(true, message);
  factory UpdateResult.error(String error) => UpdateResult._(false, error);
}