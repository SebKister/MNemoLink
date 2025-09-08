import 'dart:async';
import 'dart:io';
import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

// Local imports
import 'models/models.dart';
import 'services/services.dart';
import 'widgets/widgets.dart';

void main() async {
  // Initialize Flutter binding
  if (!Platform.isAndroid && !Platform.isIOS) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 768),
      center: true,
      minimumSize: Size(1024, 600),
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  if (Platform.isIOS) {
    DartPingIOS.register();
    if (kDebugMode) debugPrint("main(): Registered iOS");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNemo Link',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
      home: const MyHomePage(title: 'MNemo Link'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Services
  late final DeviceCommunicationService _deviceService;
  late final NetworkService _networkService;
  late final DataProcessingService _dataService;
  late final FileService _fileService;
  late final FirmwareUpdateService _firmwareService;
  
  // Data
  SectionList sections = SectionList();
  List<int> transferBuffer = [];
  bool dmpLoaded = false;
  UnitType unitType = UnitType.metric;
  
  // Device state
  bool connected = false;
  bool detected = false;
  bool detectedOnly = false;
  String nameDevice = "";
  int stabilizationFactor = 0;
  int clickThreshold = 30;
  int clickBMDurationFactor = 100;
  int safetySwitchON = -1;
  int doubleTap = -1;
  List<String> wifiList = [];
  
  // Colors
  Color pickerColor = const Color(0xff443a49);
  Color readingAColor = const Color(0x00000000);
  Color readingBColor = const Color(0x00000000);
  Color standbyColor = const Color(0x00000000);
  Color stabilizeColor = const Color(0x00000000);
  Color readyColor = const Color(0x00000000);
  
  // Time and version info
  int timeON = 0;
  int timeSurvey = 0;
  int firmwareVersionMajor = 0;
  int firmwareVersionMinor = 0;
  int firmwareVersionRevision = 0;
  int firmwareVersionBuild = 0;
  int latestFirmwareVersionMajor = 0;
  int latestFirmwareVersionMinor = 0;
  int latestFirmwareVersionRevision = 0;
  bool firmwareUpgradeAvailable = false;
  bool updatingFirmware = false;
  String upgradeFirmwarePath = "";
  String urlLatestFirmware = "";
  
  // Software update info
  int latestSoftwareVersionMajor = 0;
  int latestSoftwareVersionMinor = 0;
  int latestSoftwareVersionRevision = 0;
  int softwareVersionMajor = 0;
  int softwareVersionMinor = 0;
  int softwareVersionRevision = 0;
  bool softwareUpgradeAvailable = false;
  bool updatingSoftware = false;
  String urlLatestSoftware = "";
  String upgradeSoftwarePath = "";
  double downloadProgressValue = 0.0;
  
  // Network
  String ipMNemo = "";
  bool networkDeviceFound = false;
  bool scanningNetwork = false;
  String networkScanProgress = "";
  
  // Drag and drop
  bool _isDragging = false;
  
  // CLI
  List<String> cliHistory = [""];
  List<String> cliCommandHistory = [""];
  final cliScrollController = ScrollController();
  
  // Date/Time format
  int dateFormat = -1;
  int timeFormat = -1;
  
  // Compass calibration
  int xCompass = 0;
  int yCompass = 0;
  int zCompass = 0;
  int calMode = -1;
  
  // Factory settings locks
  bool factorySettingsLockSafetyON = true;
  bool factorySettingsLock = true;
  bool factorySettingsLockSlider = true;
  bool factorySettingsLockBMDuration = true;
  bool factorySettingsLockStabilizationFactor = true;
  bool factorySettingsDoubleTapON = true;
  
  // Controllers
  var ipController = TextEditingController();
  
  // Package info
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _deviceService = DeviceCommunicationService();
    _networkService = NetworkService();
    _dataService = DataProcessingService();
    _fileService = FileService();
    _firmwareService = FirmwareUpdateService(_deviceService);
    
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initPackageInfo();
    await _initPrefs();
    
    if (!Platform.isAndroid && !Platform.isIOS) {
      await _initMnemoPort();
      _initPeriodicTask();
      await _getLatestSoftwareAvailable();
    }
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
    var splits = _packageInfo.version.split('.');
    softwareVersionMajor = int.parse(splits[0]);
    softwareVersionMinor = int.parse(splits[1]);
    softwareVersionRevision = int.parse(splits[2]);
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    ipMNemo = prefs.getString('ipMNemo') ?? "192.168.4.1";
    ipController.text = ipMNemo;
    await _syncNetworkDeviceFound();
  }

  Future<void> _syncNetworkDeviceFound() async {
    final isFound = await _networkService.scanIPForMNemo(ipMNemo);
    setState(() {
      networkDeviceFound = isFound;
    });
  }

  Future<void> _initMnemoPort() async {
    setState(() {
      updatingFirmware = false;
      connected = false;
      detected = false;
      detectedOnly = false;
    });

    final result = await _deviceService.initializeMnemoPort();
    
    setState(() {
      connected = result.isConnected;
      detected = result.isDetected;
      detectedOnly = result.status == DeviceConnectionStatus.detectedOnly;
    });

    if (result.isConnected) {
      try {
        await _getCurrentName();
        await _getTimeON();
        await _getTimeSurvey();
        await _getDeviceFirmware();
        await _getLatestFirmwareAvailable();
      } catch (e) {
        setState(() {
          detectedOnly = true;
          connected = false;
        });
        await _showNonResponsiveWarning();
      }
    } else if (result.hasError) {
      if (result.status == DeviceConnectionStatus.detectedOnly) {
        await _showNonResponsiveWarning();
      }
    }
  }

  void _initPeriodicTask() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (connected && !_deviceService.isSerialBusy) {
        final isStillConnected = await _deviceService.checkConnection();
        if (!isStillConnected) {
          setState(() {
            connected = false;
          });
        }
      }
    });
  }

  // Event handlers
  void _onReset() {
    setState(() {
      dmpLoaded = false;
      sections.clear();
      transferBuffer.clear();
    });
  }

  Future<void> _onReadData() async {
    final result = await _deviceService.executeCLICommand("getdata");
    if (result.success) {
      transferBuffer = result.data;
      await _analyzeTransferBuffer();
    }
  }

  Future<void> _onOpenDMP() async {
    final result = await _fileService.openDMPFiles();
    if (result.success && result.hasResults) {
      await _processMultipleFiles(result);
    }
  }

  Future<void> _processMultipleFiles(MultiFileResult result) async {
    int processedCount = 0;
    final successfulFiles = result.successfulFiles;
    final failedFiles = result.failedFiles;

    for (final fileResult in successfulFiles) {
      if (fileResult.hasData) {
        transferBuffer = fileResult.data!;
        final dataResult = await _dataService.processTransferBuffer(transferBuffer, unitType);
        
        if (dataResult.success) {
          setState(() {
            sections.mergeSections(dataResult.sections);
            dmpLoaded = true;
          });
          processedCount++;
          
          if (dataResult.brokenSegmentDetected) {
            await _showBrokenSegmentWarning();
          }
        }
      }
    }

    // Show summary message
    String message = "Processed $processedCount files successfully";
    if (failedFiles.isNotEmpty) {
      message += "\n${failedFiles.length} files failed to load:";
      for (final failed in failedFiles) {
        message += "\n• ${failed.fileName}: ${failed.error}";
      }
    }
    
    if (mounted) {
      if (failedFiles.isNotEmpty) {
        _showErrorMessage(message);
      } else {
        _showMessage(message);
      }
    }
  }

  // Handle dropped files
  Future<void> _onFilesDropped(List<String> filePaths) async {
    final dmpFiles = filePaths.where((path) => path.toLowerCase().endsWith('.dmp')).toList();
    
    if (dmpFiles.isEmpty) {
      _showErrorMessage("No DMP files found in dropped files");
      return;
    }

    try {
      final fileResults = <FileProcessingResult>[];
      
      for (final filePath in dmpFiles) {
        try {
          final file = File(filePath);
          final fileName = file.path.split(Platform.pathSeparator).last;
          final transferBuffer = await _fileService.parseDMPFile(file);
          
          fileResults.add(FileProcessingResult.success(
            fileName: fileName,
            data: transferBuffer,
          ));
        } catch (e) {
          final fileName = filePath.split(Platform.pathSeparator).last;
          fileResults.add(FileProcessingResult.error(
            fileName: fileName,
            error: "Failed to parse: $e",
          ));
        }
      }

      final result = MultiFileResult.success(fileResults);
      await _processMultipleFiles(result);
      
    } catch (e) {
      _showErrorMessage("Error processing dropped files: $e");
    }
  }

  Future<void> _analyzeTransferBuffer() async {
    final result = await _dataService.processTransferBuffer(transferBuffer, unitType);
    
    if (result.success) {
      setState(() {
        sections.mergeSections(result.sections);
      });
      
      if (result.brokenSegmentDetected) {
        await _showBrokenSegmentWarning();
      }
    }
  }

  Future<void> _onNetworkScan() async {
    setState(() {
      scanningNetwork = true;
      ipController.text = "Scanning in progress";
    });

    var wifiIP = await NetworkInfo().getWifiIP();
    wifiIP ??= ipMNemo; // Fallback for macOS Sonoma

    await for (final result in _networkService.scanNetworkForMNemo(wifiIP)) {
      if (!scanningNetwork) break; // User stopped scan
      
      if (result.isScanning) {
        setState(() {
          networkScanProgress = "${result.ipAddress} ...";
        });
      } else if (result.isFound) {
        setState(() {
          ipController.text = result.ipAddress!;
          ipMNemo = result.ipAddress!;
          scanningNetwork = false;
          networkDeviceFound = true;
        });
        return;
      } else if (result.isCompleted) {
        setState(() {
          ipController.text = "No device found";
          scanningNetwork = false;
        });
        return;
      }
    }
  }

  void _onNetworkScanStop() {
    setState(() {
      scanningNetwork = false;
    });
  }

  Future<void> _onNetworkDMP() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ipMNemo', ipMNemo);

    await _syncNetworkDeviceFound();
    if (!networkDeviceFound) return;

    final result = await _networkService.downloadDMPData(ipMNemo);
    if (result.success && result.hasData) {
      transferBuffer = result.data;
      setState(() {
        dmpLoaded = transferBuffer.isNotEmpty;
      });
      await _analyzeTransferBuffer();
    }
  }

  void _onRefreshMnemo() {
    _initMnemoPort();
  }

  void _onIPChanged(String value) {
    ipMNemo = value;
    if (_fileService.isValidIPFormat(value)) {
      _syncNetworkDeviceFound();
    }
  }

  // CLI Command handlers
  Future<void> _onExecuteCLICommand(String command) async {
    final result = await _deviceService.executeCLICommand(command);
    
    setState(() {
      if (result.success) {
        cliHistory.add("c:$command");
        if (result.data.isNotEmpty) {
          cliHistory.add("a:${result.responseString}");
        }
      } else {
        cliHistory.add("c:$command");
        cliHistory.add("e:${result.error}");
      }
    });

    if (!cliCommandHistory.contains(command)) {
      setState(() {
        cliCommandHistory.add(command);
      });
    }

    // Handle special commands
    switch (command.split(" ").first.trim()) {
      case "getdata":
        transferBuffer = result.data;
        await _analyzeTransferBuffer();
        break;
      case "syncdatetime":
        await _syncDateTime();
        break;
    }
  }

  Future<void> _syncDateTime() async {
    final date = DateTime.now();
    final dateData = [
      date.year % 100,
      date.month,
      date.day,
      date.hour,
      date.minute,
    ];
    
    final result = await _deviceService.executeCLICommandWithData("syncdatetime", dateData);
    setState(() {
      if (result.success) {
        cliHistory.add("a:DateTime$date");
      } else {
        cliHistory.add("e:Error in DateTime");
      }
    });
  }

  void _scrollDown() {
    cliScrollController.animateTo(
      cliScrollController.position.maxScrollExtent,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 1000),
    );
  }

  // Selection handlers
  void _onSectionSelectionChanged(Section section, bool selected) {
    setState(() {
      section.isSelected = selected;
    });
  }

  void _onToggleSelectAll() {
    setState(() {
      sections.toggleSelectAll();
    });
  }

  // Export handlers
  Future<void> _onSaveDMP() async {
    await _handleExportOperation(() => _fileService.saveDMPFileFromSections(sections, unitType));
  }

  Future<void> _onExportXLS() async {
    await _handleSelectedSectionsExport((sections) => _fileService.saveExcelFile(sections, unitType));
  }

  Future<void> _onExportSVX() async {
    await _handleSelectedSectionsExport((sections) => _fileService.saveSurvexFile(sections, unitType));
  }

  Future<void> _onExportTH() async {
    await _handleSelectedSectionsExport((sections) => _fileService.saveTherionFile(sections, unitType));
  }

  /// Helper method for handling export operations with error handling
  Future<void> _handleExportOperation(Future<FileResult> Function() exportFunction) async {
    try {
      final result = await exportFunction();
      if (result.success && mounted) {
        _showMessage(result.message ?? 'Export completed successfully');
      } else if (!result.success && mounted) {
        _showErrorMessage(result.error ?? 'Export failed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Export failed: $e');
      }
    }
  }

  /// Helper method for exports that use selected sections
  Future<void> _handleSelectedSectionsExport(Future<FileResult> Function(SectionList) exportFunction) async {
    final selectedSectionsList = SectionList(sections: sections.selectedSections);
    await _handleExportOperation(() => exportFunction(selectedSectionsList));
  }

  /// Show success message to user
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error message to user
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Device settings getters (simplified - full implementation would call device)
  Future<void> _getCurrentName() async {
    final result = await _deviceService.executeCLICommand("getname");
    if (result.success) {
      nameDevice = result.responseString;
    }
  }

  Future<void> _getTimeON() async {
    final result = await _deviceService.executeCLICommand("gettimeon");
    if (result.success) {
      timeON = int.parse(result.responseString);
    }
  }

  Future<void> _getTimeSurvey() async {
    final result = await _deviceService.executeCLICommand("gettimesurvey");
    if (result.success) {
      timeSurvey = int.parse(result.responseString);
    }
  }

  Future<void> _getDeviceFirmware() async {
    final result = await _deviceService.executeCLICommand("getfirmwareversion");
    if (result.success) {
      final versionString = result.responseString;
      final splits = versionString.split('.');
      final splitsplus = splits[2].split('+');
      setState(() {
        firmwareVersionMajor = int.parse(splits[0]);
        firmwareVersionMinor = int.parse(splits[1]);
        firmwareVersionRevision = int.parse(splitsplus[0]);
        firmwareVersionBuild = int.parse(splitsplus[1]);
      });
    }
  }

  Future<void> _getLatestFirmwareAvailable() async {
    final result = await _firmwareService.checkLatestFirmware();
    if (!result.hasError) {
      final currentVersion = "$firmwareVersionMajor.$firmwareVersionMinor.$firmwareVersionRevision";
      final isNewer = _firmwareService.isNewerVersion(currentVersion, result.version!);
      
      setState(() {
        latestFirmwareVersionMajor = _firmwareService.parseVersion(result.version!)[0];
        latestFirmwareVersionMinor = _firmwareService.parseVersion(result.version!)[1];
        latestFirmwareVersionRevision = _firmwareService.parseVersion(result.version!)[2];
        firmwareUpgradeAvailable = isNewer;
        urlLatestFirmware = result.downloadUrl!;
      });
    }
  }

  Future<void> _getLatestSoftwareAvailable() async {
    final result = await _firmwareService.checkLatestSoftware();
    if (!result.hasError) {
      final currentVersion = "$softwareVersionMajor.$softwareVersionMinor.$softwareVersionRevision";
      final isNewer = _firmwareService.isNewerVersion(currentVersion, result.version!);
      
      setState(() {
        latestSoftwareVersionMajor = _firmwareService.parseVersion(result.version!)[0];
        latestSoftwareVersionMinor = _firmwareService.parseVersion(result.version!)[1];
        latestSoftwareVersionRevision = _firmwareService.parseVersion(result.version!)[2];
        softwareUpgradeAvailable = isNewer;
        urlLatestSoftware = result.downloadUrl!;
        upgradeSoftwarePath = result.savePath!;
      });
    }
  }

  // Update handlers
  Future<void> _onUpdateFirmware() async {
    final approved = await _showFirmwareUpdateDialog();
    if (approved != true) return;

    setState(() {
      updatingFirmware = true;
    });

    final result = await _firmwareService.updateFirmware(urlLatestFirmware);
    
    setState(() {
      updatingFirmware = false;
    });

    if (result.success) {
      await _initMnemoPort(); // Reconnect after update
    }
    // Handle result (show dialog, etc.)
  }

  Future<void> _onUpdateSoftware() async {
    final approved = await _showSoftwareUpdateDialog();
    if (approved != true) return;

    setState(() {
      downloadProgressValue = 0;
      updatingSoftware = true;
    });

    final result = await _firmwareService.downloadSoftwareUpdate(
      urlLatestSoftware,
      upgradeSoftwarePath,
      (progress) {
        setState(() {
          downloadProgressValue = progress;
        });
      },
    );

    setState(() {
      updatingSoftware = false;
    });

    if (result.success) {
      await _showSoftwareDownloadFinishedDialog();
    }
  }

  // Dialog methods
  Future<bool?> _showFirmwareUpdateDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('MNemo Firmware Update to v$latestFirmwareVersionMajor.$latestFirmwareVersionMinor.$latestFirmwareVersionRevision'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('This will automatically update the firmware $firmwareVersionMajor.$firmwareVersionMinor.$firmwareVersionRevision of your MNemo to the latest version'),
                const Text(
                  'Do not disconnect the device during the process which can take up to 1 min',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (Platform.isLinux)
                  const Text('Linux users have to mount the RPI-RP2 USB drive that will appear when the MNemo goes in update mode.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Approve'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showSoftwareUpdateDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Software Update to v$latestSoftwareVersionMajor.$latestSoftwareVersionMinor.$latestSoftwareVersionRevision'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('This will download MnemoLink v$latestSoftwareVersionMajor.$latestSoftwareVersionMinor.$latestSoftwareVersionRevision in your Downloads folder'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Approve'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSoftwareDownloadFinishedDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download completed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('The MNemoLink update file has been successfully downloaded as $upgradeSoftwarePath'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNonResponsiveWarning() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection failed'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('A device was found but it was not responding'),
                Text('Make sure the main menu screen is displayed than press the Connect button again'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBrokenSegmentWarning() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Broken segment'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Broken segment detected and partially recovered'),
                Text('This usually happens when device hard resets or when segments is not finished and device is turned off'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Color picker functionality (for future settings implementation)
  // void _changeColor(Color color) {
  //   setState(() => pickerColor = color);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SoftwareUpdateBar(
              softwareUpgradeAvailable: softwareUpgradeAvailable,
              updatingSoftware: updatingSoftware,
              downloadProgressValue: downloadProgressValue,
              latestSoftwareVersion: "v$latestSoftwareVersionMajor.$latestSoftwareVersionMinor.$latestSoftwareVersionRevision",
              onUpdateSoftware: _onUpdateSoftware,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title),
                Text(
                  style: const TextStyle(fontSize: 12),
                  _packageInfo.version,
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!Platform.isAndroid && !Platform.isIOS)
            ConnectionStatusBar(
              connected: connected,
              detected: detected,
              detectedOnly: detectedOnly,
              serialBusy: _deviceService.isSerialBusy,
              firmwareUpgradeAvailable: firmwareUpgradeAvailable,
              updatingFirmware: updatingFirmware,
              nameDevice: nameDevice,
              mnemoPortAddress: _deviceService.portAddress,
              serialNumber: _deviceService.serialNumber,
              firmwareVersion: "v$latestFirmwareVersionMajor.$latestFirmwareVersionMinor.$latestFirmwareVersionRevision",
              timeON: timeON,
              timeSurvey: timeSurvey,
              onRefreshMnemo: _onRefreshMnemo,
              onUpdateFirmware: _onUpdateFirmware,
            ),
        ],
      ),
      body: _buildDragTarget(
        (!connected && !dmpLoaded)
            ? WelcomeScreen(
                scanningNetwork: scanningNetwork,
                networkDeviceFound: networkDeviceFound,
                networkScanProgress: networkScanProgress,
                ipController: ipController,
                ipMNemo: ipMNemo,
                onRefreshMnemo: _onRefreshMnemo,
                onOpenDMP: _onOpenDMP,
                onNetworkScan: _onNetworkScan,
                onNetworkScanStop: _onNetworkScanStop,
                onNetworkDMP: _onNetworkDMP,
                onIPChanged: _onIPChanged,
              )
            : _buildMainInterface(),
      ),
    );
  }

  Widget _buildDragTarget(Widget child) {
    // For desktop platforms, wrap with drag target
    if (Platform.isAndroid || Platform.isIOS) {
      return child;
    }
    
    return DropTarget(
      onDragDone: (details) async {
        setState(() {
          _isDragging = false;
        });
        
        final files = details.files;
        final dmpFiles = files
            .where((file) => file.path.toLowerCase().endsWith('.dmp'))
            .map((file) => file.path)
            .toList();
        
        if (dmpFiles.isNotEmpty) {
          await _onFilesDropped(dmpFiles);
        }
      },
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      child: Stack(
        children: [
          child,
          if (_isDragging)
            Container(
              color: Colors.blue.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.file_upload,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Drop DMP files here to load them',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainInterface() {
    return DefaultTabController(
      length: (!Platform.isAndroid && !Platform.isIOS) ? 3 : 1,
      initialIndex: 0,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.blueGrey,
            tabs: [
              const Tab(text: 'Data'),
              if (!Platform.isAndroid && !Platform.isIOS)
                const Tab(text: 'Settings'),
              if (!Platform.isAndroid && !Platform.isIOS)
                const Tab(text: 'CLI'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDataTab(),
                if (!Platform.isAndroid && !Platform.isIOS)
                  _buildSettingsTab(),
                if (!Platform.isAndroid && !Platform.isIOS)
                  _buildCLITab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab() {
    return Column(
      children: [
        DataToolbar(
          serialBusy: _deviceService.isSerialBusy,
          connected: connected,
          hasData: transferBuffer.isNotEmpty,
          hasSections: sections.isNotEmpty,
          hasSelectedSections: sections.selectedSections.isNotEmpty,
          allSectionsSelected: sections.allSelected,
          onReset: _onReset,
          onReadData: _onReadData,
          onOpenDMP: _onOpenDMP,
          onSaveDMP: _onSaveDMP,
          onExportXLS: _onExportXLS,
          onExportSVX: _onExportSVX,
          onExportTH: _onExportTH,
          onToggleSelectAll: _onToggleSelectAll,
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(color: Colors.black26),
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              scrollDirection: Axis.vertical,
              children: sections.sections
                  .map((e) => SectionCard(e, onSelectionChanged: _onSectionSelectionChanged))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    if (!connected) {
      return Column(
        children: [
          const Text("Connect the Mnemo to your computer and press the refresh button"),
          IconButton(
            onPressed: _onRefreshMnemo,
            icon: const Icon(Icons.refresh),
            tooltip: "Search for Device",
          ),
        ],
      );
    }
    
    // Settings implementation would go here
    // For now, return placeholder
    return const Center(
      child: Text("Settings interface would be implemented here"),
    );
  }

  Widget _buildCLITab() {
    if (!connected) {
      return Column(
        children: [
          const Text("Connect the Mnemo to your computer and press the refresh button"),
          IconButton(
            onPressed: _onRefreshMnemo,
            icon: const Icon(Icons.refresh),
            tooltip: "Search for Device",
          ),
        ],
      );
    }
    
    return CLIInterface(
      serialBusy: _deviceService.isSerialBusy,
      cliHistory: cliHistory,
      cliScrollController: cliScrollController,
      onExecuteCLICommand: _onExecuteCLICommand,
      onScrollDown: _scrollDown,
    );
  }

  @override
  void dispose() {
    _deviceService.dispose();
    _networkService.dispose();
    _firmwareService.dispose();
    super.dispose();
  }
}