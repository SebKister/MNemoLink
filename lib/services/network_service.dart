import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for network-based communication with MNemo devices
class NetworkService {
  static const String _mnemoIdentifier = "MNEMO IS HERE";
  static const Duration _defaultTimeout = Duration(seconds: 2);
  
  final Dio _dio;
  
  NetworkService() : _dio = Dio() {
    _dio.options.receiveTimeout = _defaultTimeout;
    _dio.options.connectTimeout = _defaultTimeout;
  }

  /// Check if the given IP address hosts a MNemo device
  Future<bool> scanIPForMNemo(String ipAddress) async {
    try {
      // First ping the IP to check basic connectivity
      final ping = Ping(ipAddress, count: 1, timeout: 1);
      final pingResult = await ping.stream.first;
      
      if (pingResult.error?.error == ErrorType.requestTimedOut ||
          pingResult.error?.error == ErrorType.unknown ||
          pingResult.response == null) {
        return false;
      }

      // Then check if it's actually a MNemo device
      if (kDebugMode) {
        debugPrint("Checking MNemo at IP: $ipAddress");
      }
      
      final response = await _dio.get("http://$ipAddress/IsMNemoHere");
      return response.data.toString().contains(_mnemoIdentifier);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error scanning IP $ipAddress: $e");
      }
      return false;
    }
  }

  /// Scan a network range for MNemo devices
  Stream<NetworkScanResult> scanNetworkForMNemo(String baseIP) async* {
    final lastDotIndex = baseIP.lastIndexOf(".");
    if (lastDotIndex == -1) {
      yield NetworkScanResult.error("Invalid IP format");
      return;
    }
    
    final ipPrefix = baseIP.substring(0, lastDotIndex);
    
    // For mobile platforms, scan sequentially to avoid overwhelming the network
    if (Platform.isAndroid || Platform.isIOS) {
      for (int i = 1; i < 255; i++) {
        final currentIP = "$ipPrefix.$i";
        yield NetworkScanResult.scanning(currentIP);
        
        if (await scanIPForMNemo(currentIP)) {
          yield NetworkScanResult.found(currentIP);
          return;
        }
      }
    } else {
      // For desktop, scan in parallel for better performance
      final futures = <Future<String?>>[];
      
      for (int i = 1; i < 255; i++) {
        final currentIP = "$ipPrefix.$i";
        futures.add(_scanSingleIP(currentIP));
      }
      
      for (int i = 0; i < futures.length; i++) {
        final currentIP = "$ipPrefix.${i + 1}";
        yield NetworkScanResult.scanning(currentIP);
        
        final result = await futures[i];
        if (result != null) {
          yield NetworkScanResult.found(result);
          return;
        }
      }
    }
    
    yield NetworkScanResult.completed();
  }

  /// Scan a single IP address (helper for parallel scanning)
  Future<String?> _scanSingleIP(String ipAddress) async {
    if (await scanIPForMNemo(ipAddress)) {
      return ipAddress;
    }
    return null;
  }

  /// Download DMP data from a network-connected MNemo device
  Future<NetworkDownloadResult> downloadDMPData(String ipAddress) async {
    try {
      // Verify the device is still available
      if (!await scanIPForMNemo(ipAddress)) {
        return NetworkDownloadResult.error("Device not found at $ipAddress");
      }

      // Get temporary directory for download
      final tempDir = await getTemporaryDirectory();
      const fileName = 'mnemodata.txt';
      final filePath = '${tempDir.path}/$fileName';
      
      // Download the data
      final downloadURL = "http://$ipAddress/Download";
      await _dio.download(downloadURL, filePath);
      
      // Read and parse the downloaded data
      final file = File(filePath);
      final content = await file.readAsString();
      final splits = content.split(";");
      
      final transferBuffer = splits
          .map((e) => (int.tryParse(e) == null) ? 0 : int.parse(e))
          .toList();
      
      return NetworkDownloadResult.success(transferBuffer);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error downloading DMP data: $e");
      }
      return NetworkDownloadResult.error("Download failed: $e");
    }
  }

  /// Validate IP address format
  bool isValidIPFormat(String ipAddress) {
    final parts = ipAddress.split(".");
    
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0 || number > 255) {
        return false;
      }
    }
    
    return true;
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}

/// Result of network scanning operation
class NetworkScanResult {
  final NetworkScanStatus status;
  final String? ipAddress;
  final String? message;

  const NetworkScanResult._(this.status, this.ipAddress, this.message);

  factory NetworkScanResult.scanning(String ipAddress) =>
      NetworkScanResult._(NetworkScanStatus.scanning, ipAddress, null);

  factory NetworkScanResult.found(String ipAddress) =>
      NetworkScanResult._(NetworkScanStatus.found, ipAddress, null);

  factory NetworkScanResult.completed() =>
      NetworkScanResult._(NetworkScanStatus.completed, null, "Scan completed");

  factory NetworkScanResult.error(String error) =>
      NetworkScanResult._(NetworkScanStatus.error, null, error);

  bool get isFound => status == NetworkScanStatus.found;
  bool get isScanning => status == NetworkScanStatus.scanning;
  bool get isCompleted => status == NetworkScanStatus.completed;
  bool get hasError => status == NetworkScanStatus.error;
}

enum NetworkScanStatus {
  scanning,
  found,
  completed,
  error,
}

/// Result of network download operation
class NetworkDownloadResult {
  final bool success;
  final List<int> data;
  final String? error;

  const NetworkDownloadResult._(this.success, this.data, this.error);

  factory NetworkDownloadResult.success(List<int> data) =>
      NetworkDownloadResult._(true, data, null);

  factory NetworkDownloadResult.error(String error) =>
      NetworkDownloadResult._(false, <int>[], error);

  bool get hasData => data.isNotEmpty;
}