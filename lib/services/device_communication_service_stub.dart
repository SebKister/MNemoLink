import 'dart:async';
import 'dart:convert';

/// Mobile/Web stub implementation for DeviceCommunicationService
/// Serial port functionality is not available on mobile platforms
class DeviceCommunicationService {
  static const String _notSupportedMessage = "Serial port communication is not supported on this platform";
  
  bool _serialBusy = false;
  
  // Getters
  bool get isConnected => false;
  bool get isDetected => false;
  bool get isSerialBusy => _serialBusy;
  String get portAddress => "";
  String? get serialNumber => null;

  /// Find the MNemo device address - not supported on mobile
  String getMnemoAddress() {
    return "";
  }

  /// Initialize the MNemo port connection - not supported on mobile
  Future<DeviceConnectionResult> initializeMnemoPort() async {
    return DeviceConnectionResult.error(_notSupportedMessage);
  }

  /// Execute a CLI command - not supported on mobile
  Future<CommandResult> executeCLICommand(String rawCommand) async {
    return CommandResult.error(_notSupportedMessage);
  }

  /// Execute a command with data - not supported on mobile
  Future<CommandResult> executeCLICommandWithData(String command, List<int> data) async {
    return CommandResult.error(_notSupportedMessage);
  }

  /// Check if the connection is still active - always false on mobile
  Future<bool> checkConnection() async {
    return false;
  }

  /// Set up firmware update mode - not supported on mobile
  Future<bool> enterFirmwareUpdateMode() async {
    return false;
  }

  /// Dispose resources - no-op on mobile
  void dispose() {
    _serialBusy = false;
  }
}

/// Result of device connection attempt
class DeviceConnectionResult {
  final DeviceConnectionStatus status;
  final String message;
  final String? portAddress;

  const DeviceConnectionResult._(this.status, this.message, this.portAddress);

  factory DeviceConnectionResult.connected(String portAddress) =>
      DeviceConnectionResult._(DeviceConnectionStatus.connected, "Connected", portAddress);

  factory DeviceConnectionResult.detectedOnly(String portAddress) =>
      DeviceConnectionResult._(DeviceConnectionStatus.detectedOnly, "Detected but connection failed", portAddress);

  factory DeviceConnectionResult.notDetected() =>
      DeviceConnectionResult._(DeviceConnectionStatus.notDetected, "Device not detected", null);

  factory DeviceConnectionResult.error(String error) =>
      DeviceConnectionResult._(DeviceConnectionStatus.error, error, null);

  bool get isConnected => status == DeviceConnectionStatus.connected;
  bool get isDetected => status == DeviceConnectionStatus.detectedOnly || isConnected;
  bool get hasError => status == DeviceConnectionStatus.error;
}

enum DeviceConnectionStatus {
  connected,
  detectedOnly,
  notDetected,
  error,
}

/// Result of a CLI command execution
class CommandResult {
  final bool success;
  final String? command;
  final List<int> data;
  final String? error;

  const CommandResult._(this.success, this.command, this.data, this.error);

  factory CommandResult.success(String command, List<int> data) =>
      CommandResult._(true, command, data, null);

  factory CommandResult.error(String error) =>
      CommandResult._(false, null, <int>[], error);

  String get responseString => utf8.decode(data, allowMalformed: true).trim();
}