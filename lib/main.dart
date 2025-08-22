import 'dart:async';
import 'dart:io';
import 'package:dart_ping_ios/dart_ping_ios.dart';
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
  // Line tension constants
  static const double _defaultLineTensionThreshold = 0.3;
  static const double _defaultAzimuthCorrectionStrength = 0.2;
  static const LineTensionAdjustmentMethod _defaultAdjustmentMethod = LineTensionAdjustmentMethod.useAverageAngle;
  static const bool _defaultEnableValidation = true;
  
  // UI constants
  static const double _azimuthSliderMin = -0.95;
  static const double _azimuthSliderMax = 0.95;
  static const int _azimuthSliderDivisions = 38; // 39 positions: -95% to +95% in 5% increments
  static const double _thresholdSliderMin = 0.1;
  static const double _thresholdSliderMax = 1.0;
  static const int _thresholdSliderDivisions = 18;
  
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
  
  // Line tension handling settings
  bool enableLineTensionValidation = _defaultEnableValidation;
  double lineTensionThresholdRatio = _defaultLineTensionThreshold;
  LineTensionAdjustmentMethod lineTensionAdjustmentMethod = _defaultAdjustmentMethod;
  double azimuthCorrectionStrength = _defaultAzimuthCorrectionStrength;
  
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
    
    // Load line tension settings
    enableLineTensionValidation = prefs.getBool('enableLineTensionValidation') ?? _defaultEnableValidation;
    lineTensionThresholdRatio = prefs.getDouble('lineTensionThresholdRatio') ?? _defaultLineTensionThreshold;
    final adjustmentMethodIndex = prefs.getInt('lineTensionAdjustmentMethod') ?? _defaultAdjustmentMethod.index;
    lineTensionAdjustmentMethod = LineTensionAdjustmentMethod.values[adjustmentMethodIndex];
    azimuthCorrectionStrength = prefs.getDouble('azimuthCorrectionStrength') ?? _defaultAzimuthCorrectionStrength;
    
    await _syncNetworkDeviceFound();
  }

  Future<void> _saveLineTensionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableLineTensionValidation', enableLineTensionValidation);
    await prefs.setDouble('lineTensionThresholdRatio', lineTensionThresholdRatio);
    await prefs.setInt('lineTensionAdjustmentMethod', lineTensionAdjustmentMethod.index);
    await prefs.setDouble('azimuthCorrectionStrength', azimuthCorrectionStrength);
  }

  /// Helper method to save settings and reprocess data if needed
  Future<void> _updateSettingsAndReprocess() async {
    await _saveLineTensionSettings();
    if (dmpLoaded) {
      await _analyzeTransferBuffer();
    }
  }

  /// Helper method to format azimuth correction percentage
  String _formatAzimuthPercentage(double value) {
    if (value == 0.0) {
      return "0% (disabled)";
    }
    return "${value >= 0 ? '+' : ''}${(value * 100).toStringAsFixed(0)}%";
  }

  /// Helper method to format threshold percentage  
  String _formatThresholdPercentage(double value) {
    return "+${(value * 100).toStringAsFixed(0)}%";
  }

  Future<void> _resetLineTensionSettingsToDefaults() async {
    setState(() {
      enableLineTensionValidation = _defaultEnableValidation;
      lineTensionThresholdRatio = _defaultLineTensionThreshold;
      lineTensionAdjustmentMethod = _defaultAdjustmentMethod;
      azimuthCorrectionStrength = _defaultAzimuthCorrectionStrength;
    });
    
    await _updateSettingsAndReprocess();
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
    final result = await _fileService.openDMPFile();
    if (result.success && result.hasData) {
      transferBuffer = result.data!;
      setState(() {
        dmpLoaded = transferBuffer.isNotEmpty;
      });
      await _analyzeTransferBuffer();
    }
  }

  Future<void> _analyzeTransferBuffer() async {
    final result = await _dataService.processTransferBuffer(
      transferBuffer, 
      unitType,
      enableLineTensionValidation: enableLineTensionValidation,
      lineTensionThresholdRatio: lineTensionThresholdRatio,
      adjustmentMethod: lineTensionAdjustmentMethod,
      azimuthCorrectionStrength: azimuthCorrectionStrength,
    );
    
    if (result.success) {
      setState(() {
        sections.sections = result.sections;
      });
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

  // Export handlers
  Future<void> _onSaveDMP() async {
    await _fileService.saveDMPFile(transferBuffer);
    // TODO: Handle result (show snackbar, etc.)
  }

  Future<void> _onExportXLS() async {
    await _fileService.saveExcelFile(sections, unitType);
    // TODO: Handle result
  }

  Future<void> _onExportSVX() async {
    await _fileService.saveSurvexFile(sections, unitType);
    // TODO: Handle result
  }

  Future<void> _onExportTH() async {
    await _fileService.saveTherionFile(sections, unitType);
    // TODO: Handle result
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
      body: _buildMainInterface(),
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
              const Tab(text: 'Settings'),
              if (!Platform.isAndroid && !Platform.isIOS)
                const Tab(text: 'CLI'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDataTab(),
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
    // Show welcome screen when no connection and no data loaded
    if (!connected && !dmpLoaded) {
      return WelcomeScreen(
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
      );
    }
    
    // Show normal data interface when connected or data loaded
    return Column(
      children: [
        DataToolbar(
          serialBusy: _deviceService.isSerialBusy,
          connected: connected,
          hasData: transferBuffer.isNotEmpty,
          hasSections: sections.isNotEmpty,
          onReset: _onReset,
          onReadData: _onReadData,
          onOpenDMP: _onOpenDMP,
          onSaveDMP: _onSaveDMP,
          onExportXLS: _onExportXLS,
          onExportSVX: _onExportSVX,
          onExportTH: _onExportTH,
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(color: Colors.black26),
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              scrollDirection: Axis.vertical,
              children: sections.sections
                  .map((e) => SectionCard(e, key: ValueKey("${e.name}_${e.shots.length}_${e.hasAdjustedShots()}_${e.getAdjustedShotsCount()}")))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Line Tension Settings Section
              const Text(
                "Line Tension Handling",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (!dmpLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "These settings will be applied when data is loaded",
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              
              // Enable/Disable Line Tension Validation
              SettingCard(
                icon: Icons.check_circle,
                name: "Enable Line Tension Validation",
                subtitle: "Automatically detect and adjust shots where distance < depth change or suspiciously short",
                actionWidget: Switch(
                  value: enableLineTensionValidation,
                  onChanged: (value) {
                    setState(() {
                      enableLineTensionValidation = value;
                    });
                    _updateSettingsAndReprocess();
                  },
                ),
              ),
              
              if (enableLineTensionValidation) ...[
                // Threshold Ratio Setting
                SettingCard(
                  icon: Icons.tune,
                  name: "Additional Detection Threshold",
                  subtitle: "Extra margin for detecting suspicious shots beyond depth change. Current: ${_formatThresholdPercentage(lineTensionThresholdRatio)}",
                  actionWidget: Column(
                    children: [
                      Slider(
                        value: lineTensionThresholdRatio,
                        min: _thresholdSliderMin,
                        max: _thresholdSliderMax,
                        divisions: _thresholdSliderDivisions,
                        label: lineTensionThresholdRatio.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() {
                            lineTensionThresholdRatio = value;
                          });
                        },
                        onChangeEnd: (value) {
                          _updateSettingsAndReprocess();
                        },
                      ),
                      Text(
                        "Shots shorter than depth × (1 + ${lineTensionThresholdRatio.toStringAsFixed(2)}) are flagged",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                // Adjustment Method Setting
                SettingCard(
                  icon: Icons.straighten,
                  name: "Distance Adjustment Method",
                  subtitle: "How to calculate corrected distance for invalid shots",
                  actionWidget: SettingActionRadioList(
                    "Adjustment Method",
                    {
                      "Use Depth Change": LineTensionAdjustmentMethod.useDepthChange.index,
                      "Use Average Angle": LineTensionAdjustmentMethod.useAverageAngle.index,
                    },
                    (value) {
                      if (value != null) {
                        setState(() {
                          lineTensionAdjustmentMethod = LineTensionAdjustmentMethod.values[value];
                        });
                        _updateSettingsAndReprocess();
                      }
                    },
                    lineTensionAdjustmentMethod.index,
                  ),
                ),
                
                // Azimuth Correction Strength Setting - only show when using average angle
                if (lineTensionAdjustmentMethod == LineTensionAdjustmentMethod.useAverageAngle) ...[
                  SettingCard(
                    icon: Icons.explore,
                    name: "Azimuth Correction Strength",
                    subtitle: "Adjust distance based on direction changes. Current: ${_formatAzimuthPercentage(azimuthCorrectionStrength)}",
                    actionWidget: Column(
                      children: [
                        Slider(
                          value: azimuthCorrectionStrength,
                          min: _azimuthSliderMin,
                          max: _azimuthSliderMax,
                          divisions: _azimuthSliderDivisions,
                          label: _formatAzimuthPercentage(azimuthCorrectionStrength),
                          onChanged: (value) {
                            setState(() {
                              azimuthCorrectionStrength = value;
                            });
                          },
                          onChangeEnd: (value) {
                            _updateSettingsAndReprocess();
                          },
                        ),
                        Text(
                          "Range: -95% to +95% in 5% increments. Positive: lengthen, Negative: shorten, Zero: disabled",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 20),
              
              // Reset to Defaults Button
              SettingCard(
                icon: Icons.restore,
                name: "Reset Tension Adjustments to Defaults",
                subtitle: "Restore: Validation ON, Threshold 30%, Method: Average Angle, Azimuth +20%",
                actionWidget: ElevatedButton(
                  onPressed: _resetLineTensionSettingsToDefaults,
                  child: const Text("Reset to Defaults"),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Device Settings Section (only show when connected)
              if (connected) ...[
                const Text(
                  "Device Settings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text("Device settings interface would be implemented here"),
                ),
              ] else ...[
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Text(
                      "Connect to MNemo device for device settings access",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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