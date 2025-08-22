import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

// Only import serial port on desktop platforms
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Service for managing serial communication with MNemo devices
class DeviceCommunicationService {
  static const String _expectedProductName = "Nano RP2040 Connect";
  static const String _transmissionEndMarker = "MN2Over";
  static const int _defaultTimeout = 100; // 2 seconds (100 * 20ms)
  static const String _notSupportedMessage = "Serial port communication is not supported on mobile platforms";
  
  SerialPort? _mnemoPort;
  String _mnemoPortAddress = "";
  bool _serialBusy = false;
  
  /// Check if current platform supports serial communication
  bool get _isSerialSupported => !kIsWeb && 
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  
  // Getters
  bool get isConnected => _mnemoPort != null && _mnemoPortAddress.isNotEmpty;
  bool get isDetected => _mnemoPortAddress.isNotEmpty;
  bool get isSerialBusy => _serialBusy;
  String get portAddress => _mnemoPortAddress;
  String? get serialNumber => _mnemoPort?.serialNumber;

  /// Find the MNemo device address
  String getMnemoAddress() {
    if (!_isSerialSupported) return "";
    
    return SerialPort.availablePorts.firstWhere(
      (element) => SerialPort(element).productName == _expectedProductName,
      orElse: () => "",
    );
  }

  /// Initialize the MNemo port connection
  Future<DeviceConnectionResult> initializeMnemoPort() async {
    if (!_isSerialSupported) {
      return DeviceConnectionResult.error(_notSupportedMessage);
    }
    
    _serialBusy = true;
    
    try {
      _mnemoPortAddress = getMnemoAddress();
      
      if (_mnemoPortAddress.isEmpty) {
        _serialBusy = false;
        return DeviceConnectionResult.notDetected();
      }

      _mnemoPort = SerialPort(_mnemoPortAddress);
      
      final isOpenRW = _mnemoPort!.openReadWrite();
      
      _mnemoPort!.flush();
      _mnemoPort!.config = SerialPortConfig()
        ..rts = SerialPortRts.flowControl
        ..cts = SerialPortCts.flowControl
        ..dsr = SerialPortDsr.flowControl
        ..dtr = SerialPortDtr.flowControl
        ..setFlowControl(SerialPortFlowControl.rtsCts);
      
      _mnemoPort!.close();
      
      _serialBusy = false;
      
      if (isOpenRW) {
        return DeviceConnectionResult.connected(_mnemoPortAddress);
      } else {
        return DeviceConnectionResult.detectedOnly(_mnemoPortAddress);
      }
    } catch (e) {
      _serialBusy = false;
      if (_mnemoPortAddress.isNotEmpty) {
        return DeviceConnectionResult.detectedOnly(_mnemoPortAddress);
      }
      return DeviceConnectionResult.error("Failed to initialize: $e");
    }
  }

  /// Execute a CLI command and wait for response
  Future<CommandResult> executeCLICommand(String rawCommand) async {
    if (!_isSerialSupported) {
      return CommandResult.error(_notSupportedMessage);
    }
    
    if (_mnemoPort == null || _serialBusy) {
      return CommandResult.error("Device not available or busy");
    }

    _serialBusy = true;
    
    try {
      final isOpen = _mnemoPort!.openReadWrite();
      _mnemoPort!.flush();

      if (!isOpen) {
        _serialBusy = false;
        return CommandResult.error("Error opening port");
      }

      final command = rawCommand.trim();
      final commandWithNewline = '$command\n';
      
      final uint8list = Uint8List.fromList(
        utf8.decode(commandWithNewline.runes.toList()).runes.toList()
      );
      
      final nbwritten = _mnemoPort!.write(uint8list, timeout: 1000);
      
      if (nbwritten != commandWithNewline.length) {
        _mnemoPort!.close();
        _serialBusy = false;
        return CommandResult.error("Failed to write command");
      }

      // Wait for response
      final responseData = await _waitForResponse();
      _mnemoPort!.close();
      _serialBusy = false;

      return CommandResult.success(command, responseData);
      
    } catch (e) {
      _mnemoPort!.close();
      _serialBusy = false;
      return CommandResult.error("Command execution failed: $e");
    }
  }

  /// Execute a command that requires sending additional data after the command
  Future<CommandResult> executeCLICommandWithData(String command, List<int> data) async {
    if (!_isSerialSupported) {
      return CommandResult.error(_notSupportedMessage);
    }
    
    if (_mnemoPort == null || _serialBusy) {
      return CommandResult.error("Device not available or busy");
    }

    _serialBusy = true;
    
    try {
      final isOpen = _mnemoPort!.openReadWrite();
      _mnemoPort!.flush();

      if (!isOpen) {
        _serialBusy = false;
        return CommandResult.error("Error opening port");
      }

      // Send command
      final commandWithNewline = '$command\n';
      final commandBytes = Uint8List.fromList(
        utf8.decode(commandWithNewline.runes.toList()).runes.toList()
      );
      
      final nbwritten = _mnemoPort!.write(commandBytes, timeout: 1000);
      
      if (nbwritten != commandWithNewline.length) {
        _mnemoPort!.close();
        _serialBusy = false;
        return CommandResult.error("Failed to write command");
      }

      // Send additional data
      final dataBytes = Uint8List.fromList(data);
      final dataWritten = _mnemoPort!.write(dataBytes);
      
      if (dataWritten != data.length) {
        _mnemoPort!.close();
        _serialBusy = false;
        return CommandResult.error("Failed to write data");
      }

      _mnemoPort!.close();
      _serialBusy = false;
      
      return CommandResult.success(command, data);
      
    } catch (e) {
      _mnemoPort!.close();
      _serialBusy = false;
      return CommandResult.error("Command with data execution failed: $e");
    }
  }

  /// Wait for response from the device
  Future<List<int>> _waitForResponse() async {
    int counterWait = 0;
    final transferBuffer = <int>[];
    
    while (counterWait < _defaultTimeout) {
      while (_mnemoPort!.bytesAvailable <= 0) {
        await Future.delayed(const Duration(milliseconds: 20));
        counterWait++;
        
        if (counterWait >= _defaultTimeout) {
          break;
        }
      }
      
      if (counterWait >= _defaultTimeout) {
        break;
      }

      counterWait = 0;
      
      final readBuffer = _mnemoPort!.read(_mnemoPort!.bytesAvailable, timeout: 5000);
      transferBuffer.addAll(readBuffer);

      // Check if response is complete (ends with transmission marker)
      final responseString = utf8.decode(transferBuffer, allowMalformed: true);
      if (responseString.contains(_transmissionEndMarker)) {
        // Remove the transmission end marker
        final markerLength = _transmissionEndMarker.length;
        transferBuffer.removeRange(
          transferBuffer.length - markerLength, 
          transferBuffer.length
        );
        break;
      }
    }
    
    return transferBuffer;
  }

  /// Check if the connection is still active
  Future<bool> checkConnection() async {
    if (!_isSerialSupported) return false;
    if (_mnemoPort == null || _serialBusy) return false;
    
    try {
      if (!_mnemoPort!.openRead()) {
        return false;
      } else {
        _mnemoPort!.close();
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Connection check failed: $e");
      }
      return false;
    }
  }

  /// Set up firmware update mode (1200 baud)
  Future<bool> enterFirmwareUpdateMode() async {
    if (!_isSerialSupported) return false;
    if (_mnemoPort == null) return false;
    
    try {
      _mnemoPortAddress = getMnemoAddress();
      if (_mnemoPortAddress.isEmpty) return false;
      
      _mnemoPort = SerialPort(_mnemoPortAddress);
      final isOpen = _mnemoPort!.openReadWrite();
      
      if (!isOpen) return false;
      
      _mnemoPort!.flush();
      _mnemoPort!.config = SerialPortConfig()
        ..rts = SerialPortRts.flowControl
        ..cts = SerialPortCts.flowControl
        ..dsr = SerialPortDsr.flowControl
        ..dtr = SerialPortDtr.flowControl
        ..setFlowControl(SerialPortFlowControl.rtsCts)
        ..baudRate = 1200;

      _mnemoPort!.close();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Failed to enter firmware update mode: $e");
      }
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      _mnemoPort?.close();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error disposing communication service: $e");
      }
    }
    _mnemoPort = null;
    _mnemoPortAddress = "";
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