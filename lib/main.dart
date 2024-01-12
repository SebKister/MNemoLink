import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:dio/dio.dart';
import 'package:disks_desktop/disks_desktop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mnemolink/fileicon.dart';
import 'package:mnemolink/survexporter.dart';
import 'package:mnemolink/thexporter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mnemolink/excelexport.dart';
import 'package:mnemolink/sectioncard.dart';
import 'package:mnemolink/settingcard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:convert' show json, utf8;
import './section.dart';
import './shot.dart';
import './sectionlist.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
  String mnemoPortAddress = "";
  late SerialPort mnemoPort;
  bool connected = false;
  bool detectedOnly = false;
  bool detected = true;
  bool dmpLoaded = false;
  List<String> cliHistory = [""];
  List<String> cliCommandHistory = [""];
  var transferBuffer = List<int>.empty(growable: true);
  SectionList sections = SectionList();
  bool commandSent = false;
  UnitType unitType = UnitType.metric;
  int stabilizationFactor = 0;
  String nameDevice = "";
  int clickThreshold = 30;
  int clickBMDurationFactor = 100;
  int safetySwitchON = -1;
  int doubleTap = -1;
  List<String> wifiList = [];

  Color pickerColor = const Color(0xff443a49);
  Color readingAColor = const Color(0x00000000);
  Color readingBColor = const Color(0x00000000);
  Color standbyColor = const Color(0x00000000);
  Color stabilizeColor = const Color(0x00000000);
  Color readyColor = const Color(0x00000000);

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

  String ipMNemo = "";

  static const int maxRetryFirmware = 10;

  int xCompass = 0;
  int yCompass = 0;
  int zCompass = 0;
  int calMode = -1;

  bool factorySettingsLockSafetyON = true;
  bool factorySettingsLock = true;
  bool factorySettingsLockSlider = true;
  bool factorySettingsLockBMDuration = true;
  bool factorySettingsLockStabilizationFactor = true;
  bool factorySettingsDoubleTapON = true;
  bool serialBusy = false;
  bool networkDeviceFound = false;
  bool scanningNetwork = false;
  String networkScanProgress = "";

  int dateFormat = -1;
  int timeFormat = -1;

  var ipController = TextEditingController();
  final cliScrollController = ScrollController();

  final NetworkInfo _networkInfo = NetworkInfo();

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  void changeColor(Color color) {
    setState(() => pickerColor = color);
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

  @override
  void initState() {
    super.initState();

    initPrefs();
    _initPackageInfo();
    initMnemoPort();
    initPeriodicTask();
    getLatestSoftwareAvailable();
  }

  String getMnemoAddress() {
    return SerialPort.availablePorts.firstWhere(
        (element) => SerialPort(element).productName == "Nano RP2040 Connect",
        orElse: () => "");
  }

  Future<void> initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    ipMNemo = prefs.getString('ipMNemo') ?? "192.168.4.1";
    ipController.text = ipMNemo;
    await syncNetworkDeviceFound();
  }

  Future<void> syncNetworkDeviceFound() async {
    var response = await scanIPforMNemo(ipMNemo);
    setState(() {
      networkDeviceFound = response;
    });
  }

  Future<bool> scanIPforMNemo(String ipString) async {
    Dio dio = Dio();
    dio.options.receiveTimeout = const Duration(seconds: 3);
    final ping = Ping(ipString, count: 1, timeout: 1);
    try {
      //First ping ip
      var pingResult = await ping.stream.first;
      if (pingResult.error?.error == ErrorType.requestTimedOut ||
          pingResult.error?.error == ErrorType.unknown ||
          pingResult.response == null) return false;

      //Than GET IsMNemoHere to see if ip is a MNemo
      debugPrint(ipString);
      var response = await dio.get("http://$ipString/IsMNemoHere");
      return (response.data.toString().contains("MNEMO IS HERE"));
    } catch (e) {
      return false;
    }
  }

  Future<void> initMnemoPort() async {
    setState(() {
      updatingFirmware = false;
      connected = false;
      detected = false;
      detectedOnly = false;
      serialBusy = true;
    });

    mnemoPortAddress = getMnemoAddress();

    if (mnemoPortAddress.isNotEmpty) {
      setState(() {
        detected = true;
      });
      mnemoPort = SerialPort(mnemoPortAddress);

      var isopenrw = mnemoPort.openReadWrite();

      mnemoPort.flush();
      mnemoPort.config = SerialPortConfig()
        ..rts = SerialPortRts.flowControl
        ..cts = SerialPortCts.flowControl
        ..dsr = SerialPortDsr.flowControl
        ..dtr = SerialPortDtr.flowControl
        ..setFlowControl(SerialPortFlowControl.rtsCts);
      mnemoPort.close();
      try {
        await getCurrentName().then((value) => getTimeON().then((value) =>
            getTimeSurvey().then((value) => getDeviceFirmware()
                .then((value) => getLatestFirmwareAvailable()))));
        setState(() {
          detectedOnly = false;
          connected = isopenrw;
          serialBusy = false;
        });
      } catch (e) {
        setState(() {
          detectedOnly = true;
          connected = false;
          serialBusy = false;
        });
        await nonResponsiveWarning();
      }
    }
  }

  void onReset() {
    setState(() {
      dmpLoaded = false;
      sections.getSections().clear();
    });
  }

  void onReadData() {
    executeCLIAsync("getdata").then((value) => analyzeTransferBuffer());
  }

  Future<void> onOpenDMP() async {
    var result = await FilePicker.platform.pickFiles(
        dialogTitle: "Save as DMP",
        type: FileType.custom,
        allowedExtensions: ["dmp"],
        allowMultiple: false);

// The result will be null, if the user aborted the dialog
    if (result != null) {
      File file = File(result.files.first.path.toString());
      final input = file.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter(fieldDelimiter: ';'))
          .toList();

      transferBuffer.clear();
      for (var element in fields[0]) {
        if (element != "") transferBuffer.add(element);
      }
      setState(() {
        dmpLoaded = transferBuffer.isNotEmpty;
      });

      analyzeTransferBuffer();
    }
  }

  Future<void> onNetworkScan() async {
    setState(() {
      scanningNetwork = true;
      ipController.text = "Scanning in progress";
    });
    var wifiIP = await _networkInfo.getWifiIP();

    //On mac os Sonoma there no access allowed to wifi info for the moment, so using latest working IP
    wifiIP ??= ipMNemo;

    var ipPart = wifiIP.substring(0, wifiIP.lastIndexOf("."));

    List<Future<bool>> listResult = List<Future<bool>>.empty(growable: true);
    for (int j = 0; j < 256; j++) {
      listResult.add(scanIPforMNemo("$ipPart.$j"));
    }
    for (int j = 0; j < 256; j++) {
      setState(() {
        networkScanProgress = "$ipPart.$j ...";
      });
      if (await listResult[j]) {
        setState(() {
          ipController.text = "$ipPart.$j";
          ipMNemo = ipController.text;
          scanningNetwork = false;
          networkDeviceFound = true;
        });
        return;
      }
    }

    setState(() {
      ipController.text = "No device found";
      scanningNetwork = false;
    });
  }

  Future<void> onNetworkDMP() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ipMNemo', ipMNemo);

    //check if device at current ip

    await syncNetworkDeviceFound();
    if (!networkDeviceFound) return;

    var dir = await getTemporaryDirectory();

    String url = "http://$ipMNemo/Download";
    String fileName = 'mnemodata.txt';
    try {
      Dio dio = Dio();
      await dio.download(url, "${dir.path}/$fileName");
    } catch (e) {
      setState(() {
        networkDeviceFound = false;
      });
      return;
    }
    List<String> splits = List<String>.empty(growable: true);
    await File("${dir.path}/$fileName")
        .readAsString()
        .then((value) => splits = value.split(";"));
    transferBuffer = splits
        .map((e) => (int.tryParse(e) == null) ? 0 : int.parse(e))
        .toList();
    setState(() {
      dmpLoaded = transferBuffer.isNotEmpty;
    });
    analyzeTransferBuffer();
  }

  void onRefreshMnemo() {
    initMnemoPort();
  }

  void initPeriodicTask() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (connected && !serialBusy) {
        if (!mnemoPort.openRead()) {
          setState(() {
            connected = false;
          });
        } else {
          mnemoPort.close();
        }
      }
    });
  }

  Future<void> getLatestSoftwareAvailable() async {
    // Download latest release info
    var dir = await getTemporaryDirectory();
    var dirDownloads = await getDownloadsDirectory();

    String url =
        "https://api.github.com/repos/SebKister/MnemoLink/releases/latest";
    String fileName = 'mnemolink.json';
    Dio dio = Dio();
    await dio.download(url, "${dir.path}/$fileName");

    //Extract Json Data
    final data =
        await json.decode(await File("${dir.path}/$fileName").readAsString());
    String version = data['tag_name'];
    version = version.substring(1); // Remove the 'v'

    var splits = version.split('.');

    latestSoftwareVersionMajor = int.parse(splits[0]);
    latestSoftwareVersionMinor = int.parse(splits[1]);
    latestSoftwareVersionRevision = int.parse(splits[2]);

    if (latestSoftwareVersionMajor != softwareVersionMajor ||
        latestSoftwareVersionMinor != softwareVersionMinor ||
        latestSoftwareVersionRevision != softwareVersionRevision) {
      if (Platform.isLinux) {
        urlLatestSoftware = data['assets'][0]['browser_download_url'];
        upgradeSoftwarePath =
            '${dirDownloads?.path}/${data['assets'][0]['name']}';
      } else if (Platform.isMacOS) {
        urlLatestSoftware = data['assets'][1]['browser_download_url'];
        upgradeSoftwarePath =
            '${dirDownloads?.path}/${data['assets'][1]['name']}';
      } else if (Platform.isWindows) {
        urlLatestSoftware = data['assets'][2]['browser_download_url'];
        upgradeSoftwarePath =
            '${dirDownloads?.path}/${data['assets'][2]['name']}';
      }

      setState(() {
        softwareUpgradeAvailable = true;
      });
    } else {
      setState(() {
        firmwareUpgradeAvailable = false;
      });
    }
  }

  Future<void> getLatestFirmwareAvailable() async {
    // Download latest release info
    var dir = await getTemporaryDirectory();

    String url =
        "https://api.github.com/repos/SebKister/Mnemo-V2/releases/latest";
    String fileName = 'mnemofirmware.json';

    Dio dio = Dio();
    await dio.download(url, "${dir.path}/$fileName");

    //Extract Json Data
    final data =
        await json.decode(await File("${dir.path}/$fileName").readAsString());
    urlLatestFirmware = data['assets'][0]['browser_download_url'];
    String version = data['tag_name'];
    version = version.substring(1); // Remove the 'v'

    var splits = version.split('.');

    latestFirmwareVersionMajor = int.parse(splits[0]);
    latestFirmwareVersionMinor = int.parse(splits[1]);
    latestFirmwareVersionRevision = int.parse(splits[2]);

    if (latestFirmwareVersionMajor != firmwareVersionMajor ||
        latestFirmwareVersionMinor != firmwareVersionMinor ||
        latestFirmwareVersionRevision != firmwareVersionRevision) {
      upgradeFirmwarePath = '${dir.path}/mnemofirmware$version.uf2';
      setState(() {
        firmwareUpgradeAvailable = true;
      });
    } else {
      setState(() {
        firmwareUpgradeAvailable = false;
      });
    }
  }

  Future<void> nonResponsiveWarning() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection failed'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('A device was found but it was not responding'),
                Text(
                    'Make sure the main menu screen is displayed than press the Connect button again'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> showFirmwareUpdateDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'MNemo Firmware Update to v$latestFirmwareVersionMajor.$latestFirmwareVersionMinor.$latestFirmwareVersionRevision'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'This will automatically update the firmware $firmwareVersionMajor.$firmwareVersionMinor.$firmwareVersionRevision of your MNemo to the latest version'),
                const Text(
                  'Do not disconnect the device during the process which can take up to 1 min',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (Platform.isLinux)
                  const Text(
                      'Linux users have to mount the RPI-RP2 USB drive that will appear when the MNemo goes in update mode.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Approve'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> showSoftwareDownloadFinishedDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download completed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'The MNemoLink update file has been successfully downloaded as $upgradeSoftwarePath '),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> showSoftwareUpdateDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Software Update to v$latestSoftwareVersionMajor.$latestSoftwareVersionMinor.$latestSoftwareVersionRevision'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'This will download MnemoLink v$latestSoftwareVersionMajor.$latestSoftwareVersionMinor.$latestSoftwareVersionRevision in your Downloads folder'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Approve'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> onUpdateSoftware() async {
    bool? updateApproval = await showSoftwareUpdateDialog();
    if (!updateApproval!) {
      return;
    }
    setState(() {
      downloadProgressValue = 0;
      updatingSoftware = true;
    });
    Dio dio = Dio();

    await dio.download(
      urlLatestSoftware,
      upgradeSoftwarePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        setState(() {
          downloadProgressValue = received / total;
        });
      },
    );
    await showSoftwareDownloadFinishedDialog();
    setState(() {
      updatingSoftware = false;
    });
  }

  Future<void> onUpdateFirmware() async {
    bool? updateApproval = await showFirmwareUpdateDialog();
    if (!updateApproval!) {
      return;
    }

    setState(() {
      updatingFirmware = true;
      serialBusy = true;
    });

    // Download the firmware
    Dio dio = Dio();
    await dio.download(urlLatestFirmware, upgradeFirmwarePath);

    //Puts Mnemo in Boot mode by doing COM Port Open/Close at 1200bps
    mnemoPortAddress = getMnemoAddress();
    if (mnemoPortAddress == "") {
      connected = false;
    } else {
      mnemoPort = SerialPort(mnemoPortAddress);
      connected = mnemoPort.openReadWrite();
      mnemoPort.flush();
      mnemoPort.config = SerialPortConfig()
        ..rts = SerialPortRts.flowControl
        ..cts = SerialPortCts.flowControl
        ..dsr = SerialPortDsr.flowControl
        ..dtr = SerialPortDtr.flowControl
        ..setFlowControl(SerialPortFlowControl.rtsCts)
        ..baudRate = 1200;

      mnemoPort.close();
    }
    connected = false;

    // Scan for RPI RP2 Disk
    // On Linux the user is required to manual mount the drive

    final repository = DisksRepository();
    Disk disk;
    int retryCounter = 0;
    do {
      await Future.delayed(const Duration(seconds: 2));
      final disks = await repository.query;
      disk = disks
          .where((element) =>
              element.description.contains("RPI RP2") ||
              element.description.contains("RPI-RP2"))
          .first;
    } while (disk.mountpoints.isEmpty && retryCounter++ < maxRetryFirmware);

    if (retryCounter < maxRetryFirmware) {
      //Copy firmware on USB Key RPI-RP2
      if (Platform.isWindows) {
        await File(upgradeFirmwarePath)
            .copy("${disk.mountpoints[0].path}firmware.uf2");
      } else if (Platform.isLinux || Platform.isMacOS) {
        await File(upgradeFirmwarePath)
            .copy("${disk.mountpoints[0].path}/firmware.uf2");
      }

      // Required in order to give the MNemo time to reboot and update settings
      await Future.delayed(const Duration(seconds: 15));
    }
    await initMnemoPort();
    setState(() {
      updatingFirmware = false;
      serialBusy = false;
    });
  }

  int readByteFromEEProm(int address) {
    return transferBuffer.elementAt(address);
  }

  int readIntFromEEProm(int address) {
    final bytes = Uint8List.fromList(
        [transferBuffer[address], transferBuffer[address + 1]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getInt16(0);
  }

  void analyzeTransferBuffer() {
    int currentMemory = transferBuffer.length;
    int cursor = 0;

    var fileVersionValueA = 68;
    var fileVersionValueB = 89;
    var fileVersionValueC = 101;

    var shotStartValueA = 57;
    var shotStartValueB = 67;
    var shotStartValueC = 77;

    var shotEndValueA = 95;
    var shotEndValueB = 25;
    var shotEndValueC = 35;

    while (cursor < currentMemory - 2) {
      Section section = Section();

      int fileVersion = 0;
      int checkByteA = 0;
      int checkByteB = 0;
      int checkByteC = 0;

      while (fileVersion != 2 &&
          fileVersion != 3 &&
          fileVersion != 4 &&
          fileVersion != 5) {
        fileVersion = readByteFromEEProm(cursor);
        cursor++;
      }

      if (fileVersion >= 5) {
        checkByteA = readByteFromEEProm(cursor++);
        checkByteB = readByteFromEEProm(cursor++);
        checkByteC = readByteFromEEProm(cursor++);
        if (checkByteA != fileVersionValueA ||
            checkByteB != fileVersionValueB ||
            checkByteC != fileVersionValueC) return;
      }

      int year = 0;

      while ((year < 16) || (year > (DateTime.now().year - 2000))) {
        year = readByteFromEEProm(cursor);
        cursor++;
      }

      year += 2000;

      int month = readByteFromEEProm(cursor);
      cursor++;
      int day = readByteFromEEProm(cursor);
      cursor++;
      int hour = readByteFromEEProm(cursor);
      cursor++;
      int minute = readByteFromEEProm(cursor);
      cursor++;
      DateTime dateSection = DateTime(year, month, day, hour, minute);
      //  LocalDateTime dateSection = LocalDateTime.now();
      section.setDateSurvey(dateSection);
      // Read section type and name
      StringBuffer stbuilder = StringBuffer();
      stbuilder.write(utf8.decode([readByteFromEEProm(cursor++)]));
      stbuilder.write(utf8.decode([readByteFromEEProm(cursor++)]));
      stbuilder.write(utf8.decode([readByteFromEEProm(cursor++)]));
      section.setName(stbuilder.toString());
      // Read Direction  0 for In 1 for Out

      int directionIndex = readByteFromEEProm(cursor++);
      if (directionIndex == 0 || directionIndex == 1) {
        section.setDirection(SurveyDirection.values[directionIndex]);
      } else {
        break;
      }

      double conversionFactor = 0.0;
      if (unitType == UnitType.metric) {
        conversionFactor = 1.0;
      } else {
        conversionFactor = 3.28084;
      }

      Shot shot;
      do {
        shot = Shot.zero();
        int typeShot = 0;
        if (fileVersion >= 5) {
          checkByteA = readByteFromEEProm(cursor++);
          checkByteB = readByteFromEEProm(cursor++);
          checkByteC = readByteFromEEProm(cursor++);
          if (checkByteA != shotStartValueA ||
              checkByteB != shotStartValueB ||
              checkByteC != shotStartValueC) return;
        }
        typeShot = readByteFromEEProm(cursor++);

        if (typeShot > 3 || typeShot < 0) {
          break;
        }

        shot.setTypeShot(TypeShot.values[typeShot]);
        // cursor++;
        shot.setHeadingIn(readIntFromEEProm(cursor));
        cursor += 2;

        shot.setHeadingOut(readIntFromEEProm(cursor));
        cursor += 2;

        shot.setLength(readIntFromEEProm(cursor) * conversionFactor / 100.0);
        cursor += 2;

        shot.setDepthIn(readIntFromEEProm(cursor) * conversionFactor / 100.0);
        cursor += 2;

        shot.setDepthOut(readIntFromEEProm(cursor) * conversionFactor / 100.0);
        cursor += 2;

        shot.setPitchIn(readIntFromEEProm(cursor));
        cursor += 2;

        shot.setPitchOut(readIntFromEEProm(cursor));
        cursor += 2;

        if (fileVersion >= 4) {
          shot.setLeft(readIntFromEEProm(cursor) * conversionFactor / 100.0);
          cursor += 2;
          shot.setRight(readIntFromEEProm(cursor) * conversionFactor / 100.0);
          cursor += 2;
          shot.setUp(readIntFromEEProm(cursor) * conversionFactor / 100.0);
          cursor += 2;
          shot.setDown(readIntFromEEProm(cursor) * conversionFactor / 100.0);
          cursor += 2;
        }
        if (fileVersion >= 3) {
          shot.setTemperature(readIntFromEEProm(cursor));
          cursor += 2;
          shot.setHr(readByteFromEEProm(cursor++));
          shot.setMin(readByteFromEEProm(cursor++));
          shot.setSec(readByteFromEEProm(cursor++));
        } else {
          shot.setTemperature(0);
          shot.setHr(0);
          shot.setMin(0);
          shot.setSec(0);
        }

        shot.setMarkerIndex(readByteFromEEProm(cursor++));
        if (fileVersion >= 5) {
          checkByteA = readByteFromEEProm(cursor++);
          checkByteB = readByteFromEEProm(cursor++);
          checkByteC = readByteFromEEProm(cursor++);
          if (checkByteA != shotEndValueA ||
              checkByteB != shotEndValueB ||
              checkByteC != shotEndValueC) return;
        }
        section.getShots().add(shot);
      } while (shot.getTypeShot() != TypeShot.eoc);

      setState(() {
        // Adding section only if it contains data. Note : EOC shot should always be present at end of section.
        if (section.shots.length > 1) {
          sections.getSections().add(section);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double widthColorButton = 150.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (softwareUpgradeAvailable)
            IconButton(
              color: Colors.yellowAccent,
              onPressed: (!updatingSoftware) ? onUpdateSoftware : null,
              icon: const Icon(Icons.update),
              tooltip:
                  "Update Software to v$latestSoftwareVersionMajor.$latestSoftwareVersionMinor.$latestSoftwareVersionRevision",
            ),
          if (updatingSoftware)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                value: downloadProgressValue,
                color: Colors.yellow,
                strokeWidth: 5,
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title),
              Text(style: const TextStyle(fontSize: 12), _packageInfo.version)
            ],
          ),
        ]),
        actions: [
          Container(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: connected || detected
                  ? [
                      (serialBusy)
                          ? Container(
                              padding: const EdgeInsets.only(right: 30),
                              child: LoadingAnimationWidget.inkDrop(
                                  color: Colors.white60, size: 20),
                            )
                          : const SizedBox.shrink(),
                      if (connected && firmwareUpgradeAvailable)
                        IconButton(
                          color: Colors.yellowAccent,
                          onPressed:
                              (!updatingFirmware) ? onUpdateFirmware : null,
                          icon: const Icon(Icons.update),
                          tooltip:
                              "Update Firmware to v$latestFirmwareVersionMajor.$latestFirmwareVersionMinor.$latestFirmwareVersionRevision",
                        ),
                      if (connected)
                        Column(
                          children: [
                            Text(
                                "[$nameDevice] Connected on $mnemoPortAddress"),
                            Text(
                                style: const TextStyle(fontSize: 10),
                                ' SN ${mnemoPort.serialNumber} FW $firmwareVersionMajor.$firmwareVersionMinor.$firmwareVersionRevision'),
                            Text(
                                style: const TextStyle(fontSize: 9),
                                ' ON: $timeON min - Survey: $timeSurvey min')
                          ],
                        ),
                      IconButton(
                        onPressed: onRefreshMnemo,
                        icon: const Icon(Icons.refresh),
                        tooltip: "Search for Device",
                      ),
                    ]
                  : [
                      (detectedOnly)
                          ? const Text("Mnemo detected -Connection failed-")
                          : const Text("Mnemo Not detected"),
                      IconButton(
                        onPressed: onRefreshMnemo,
                        icon: const Icon(Icons.refresh),
                        tooltip: "Search for Device",
                      ),
                    ],
            ),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: (!connected && !dmpLoaded)
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: (!connected && !dmpLoaded)
            ? <Widget>[
                Center(
                  child: Column(
                    children: [
                      const Text(
                          "Connect the Mnemo to your computer and press the refresh button"),
                      IconButton(
                        onPressed: onRefreshMnemo,
                        icon: const Icon(Icons.refresh),
                        tooltip: "Search for Device",
                      ),
                      const SizedBox(
                        width: 10,
                        height: 60,
                      ),
                      const Text("Open a DMP file"),
                      FileIcon(
                        icon: Icons.file_open,
                        onPressed: onOpenDMP,
                        extension: 'DMP',
                        tooltip: "Open a DMP",
                        size: 24,
                        color: Colors.black54,
                        extensionColor: Colors.black87,
                      ),
                      const SizedBox(
                        width: 10,
                        height: 60,
                      ),
                      const Text("Download from the network"),
                      IconButton(
                        onPressed: (networkDeviceFound || scanningNetwork)
                            ? null
                            : onNetworkScan,
                        icon: const Icon(Icons.search),
                        tooltip:
                            "Scan local network for wifi connected devices",
                      ),
                      TextField(
                        textAlign: TextAlign.center,
                        controller: ipController,
                        showCursor: true,
                        onChanged: (value) {
                          ipMNemo = value;
                          syncNetworkDeviceFound();
                        },
                        autofocus: true,
                        obscureText: false,
                        decoration: InputDecoration(
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          labelText:
                              (scanningNetwork) ? networkScanProgress : "IP",
                          hintText: '[Enter the IP of the MNemo]',
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0x00000000),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4.0),
                              topRight: Radius.circular(4.0),
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0x00000000),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4.0),
                              topRight: Radius.circular(4.0),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: (!networkDeviceFound) ? null : onNetworkDMP,
                        icon: const Icon(Icons.wifi),
                        tooltip: "Download from wifi connected device",
                      ),
                    ],
                  ),
                )
              ]
            : <Widget>[
                // Generated code for this TabBar Widget...
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    initialIndex: 0,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Colors.blueGrey,
                          tabs: [
                            Tab(
                              text: 'Data',
                            ),
                            Tab(
                              text: 'Settings',
                            ),
                            Tab(
                              text: 'CLI',
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Data
                              Column(children: [
                                AppBar(
                                  actions: [
                                    IconButton(
                                      onPressed:
                                          (sections.getSections().isEmpty)
                                              ? null
                                              : onReset,
                                      icon: const Icon(Icons.backspace_rounded),
                                      tooltip: "Clear local Data",
                                    ),
                                    IconButton(
                                      onPressed: (serialBusy || !connected)
                                          ? null
                                          : onReadData,
                                      icon: const Icon(Icons.download_rounded),
                                      tooltip: "Read Data from Device",
                                    ),
                                    FileIcon(
                                      onPressed:
                                          (serialBusy) ? null : onOpenDMP,
                                      icon: Icons.file_open,
                                      extension: 'DMP',
                                      tooltip: "Open DMP file",
                                      size: 24,
                                      color: (serialBusy)
                                          ? Colors.black26
                                          : Colors.black54,
                                      extensionColor: (serialBusy)
                                          ? Colors.black26
                                          : Colors.black87,
                                    ),
                                    FileIcon(
                                      onPressed:
                                          (serialBusy || transferBuffer.isEmpty)
                                              ? null
                                              : onSaveDMP,
                                      extension: 'DMP',
                                      tooltip: "Save as DMP",
                                      size: 24,
                                      color:
                                          (serialBusy || transferBuffer.isEmpty)
                                              ? Colors.black26
                                              : Colors.black54,
                                      extensionColor:
                                          (serialBusy || transferBuffer.isEmpty)
                                              ? Colors.black26
                                              : Colors.black87,
                                    ),
                                    FileIcon(
                                      onPressed: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? null
                                          : onExportXLS,
                                      extension: 'XLS',
                                      tooltip: "Export as Excel",
                                      size: 24,
                                      color: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? Colors.black26
                                          : Colors.black54,
                                      extensionColor: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? Colors.black26
                                          : Colors.black87,
                                    ),
                                    FileIcon(
                                      onPressed: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? null
                                          : onExportSVX,
                                      extension: 'SVX',
                                      tooltip: "Export as Survex",
                                      size: 24,
                                      color: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? Colors.black26
                                          : Colors.black54,
                                      extensionColor: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? Colors.black26
                                          : Colors.black87,
                                    ),
                                    FileIcon(
                                      onPressed: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? null
                                          : onExportTH,
                                      extension: 'TH',
                                      tooltip: "Export as Therion",
                                      size: 24,
                                      color: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? Colors.black26
                                          : Colors.black54,
                                      extensionColor: (serialBusy ||
                                              sections.sections.isEmpty)
                                          ? Colors.black26
                                          : Colors.black87,
                                    ),
                                  ],
                                  backgroundColor: Colors.white30,
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                        color: Colors.black26),
                                    child: ListView(
                                      padding: const EdgeInsets.all(20),
                                      shrinkWrap: true,
                                      scrollDirection: Axis.vertical,
                                      children: sections
                                          .getSections()
                                          .map(
                                            (e) => SectionCard(e),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ]),
                              //Settings----------------------------------------
                              (!connected)
                                  ? Column(
                                      children: [
                                        const Text(
                                            "Connect the Mnemo to your computer and press the refresh button"),
                                        IconButton(
                                          onPressed: onRefreshMnemo,
                                          icon: const Icon(Icons.refresh),
                                          tooltip: "Search for Device",
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                                color: Colors.black26),
                                            child: ListView(
                                              padding: const EdgeInsets.all(20),
                                              shrinkWrap: true,
                                              scrollDirection: Axis.vertical,
                                              children: [
                                                SettingCard(
                                                  name: "Date & Time",
                                                  subtitle:
                                                      "Synchronize date and time with the computer",
                                                  icon: Icons.timer,
                                                  actionWidget: Row(children: [
                                                    SettingActionButton(
                                                        "SYNC NOW",
                                                        (serialBusy)
                                                            ? null
                                                            : () =>
                                                                onSyncDateTime()),
                                                    SettingActionButton(
                                                        "GET TIME FORMAT",
                                                        (serialBusy)
                                                            ? null
                                                            : () =>
                                                                getCurrentTimeFormat()),
                                                    SettingActionRadioList(
                                                        "",
                                                        const {
                                                          "24H": 0,
                                                          "12AM/12PM": 1,
                                                        },
                                                        (serialBusy)
                                                            ? null
                                                            : setTimeFormat,
                                                        timeFormat),
                                                    SettingActionButton(
                                                        "GET DATE FORMAT",
                                                        (serialBusy)
                                                            ? null
                                                            : () =>
                                                                getCurrentDateFormat()),
                                                    SettingActionRadioList(
                                                        "",
                                                        const {
                                                          "DD/MM": 0,
                                                          "MM/DD": 1,
                                                        },
                                                        (serialBusy)
                                                            ? null
                                                            : setDateFormat,
                                                        dateFormat),
                                                  ]),
                                                ),
                                                SettingCard(
                                                  name: "WIFI",
                                                  subtitle:
                                                      "Manage known WIFI networks",
                                                  icon: Icons.wifi,
                                                  actionWidget: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      SettingActionButton(
                                                          "GET CURRENT",
                                                          (serialBusy)
                                                              ? null
                                                              : () =>
                                                                  getCurrentWifiList()),
                                                      SettingWifiList(
                                                          wifiList,
                                                          (serialBusy)
                                                              ? null
                                                              : removeFromWifiList),
                                                      SettingWifiActionButton(
                                                          "ADD NEW",
                                                          (serialBusy)
                                                              ? null
                                                              : (e, f) =>
                                                                  addToWifiList(
                                                                      e, f)),
                                                    ],
                                                  ),
                                                ),
                                                SettingCard(
                                                  name: "Color Scheme",
                                                  subtitle:
                                                      "Colors defining survey steps",
                                                  icon:
                                                      Icons.color_lens_outlined,
                                                  actionWidget: Row(
                                                    children: [
                                                      SettingActionButton.sized(
                                                          "GET CURRENT",
                                                          (serialBusy)
                                                              ? null
                                                              : () =>
                                                                  getCurrentColorScheme(),
                                                          widthColorButton,
                                                          0.0),
                                                      Column(
                                                        children: [
                                                          SettingActionButton.sized(
                                                              "RESET TO DEFAULT",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      resetColorScheme(),
                                                              widthColorButton,
                                                              0.0),
                                                          Row(children: [
                                                            SettingActionButton.sized(
                                                                "SET READINGA",
                                                                (serialBusy)
                                                                    ? null
                                                                    : () =>
                                                                        setCurrentColorSchemeReadingA(),
                                                                widthColorButton,
                                                                0.0),
                                                            Placeholder(
                                                              fallbackWidth:
                                                                  100,
                                                              fallbackHeight:
                                                                  10,
                                                              strokeWidth: 10,
                                                              color:
                                                                  readingAColor,
                                                            ),
                                                          ]),
                                                          Row(children: [
                                                            SettingActionButton.sized(
                                                                "SET READINGB",
                                                                (serialBusy)
                                                                    ? null
                                                                    : () =>
                                                                        setCurrentColorSchemeReadingB(),
                                                                widthColorButton,
                                                                0.0),
                                                            Placeholder(
                                                              fallbackWidth:
                                                                  100,
                                                              fallbackHeight:
                                                                  10,
                                                              strokeWidth: 10,
                                                              color:
                                                                  readingBColor,
                                                            ),
                                                          ]),
                                                          Row(children: [
                                                            SettingActionButton.sized(
                                                                "SET STANDBY",
                                                                (serialBusy)
                                                                    ? null
                                                                    : () =>
                                                                        setCurrentColorSchemeStandBy(),
                                                                widthColorButton,
                                                                0.0),
                                                            Placeholder(
                                                              fallbackWidth:
                                                                  100,
                                                              fallbackHeight:
                                                                  10,
                                                              strokeWidth: 10,
                                                              color:
                                                                  standbyColor,
                                                            ),
                                                          ]),
                                                          Row(children: [
                                                            SettingActionButton.sized(
                                                                "SET READY",
                                                                (serialBusy)
                                                                    ? null
                                                                    : () =>
                                                                        setCurrentColorSchemeReady(),
                                                                widthColorButton,
                                                                0.0),
                                                            Placeholder(
                                                              fallbackWidth:
                                                                  100,
                                                              fallbackHeight:
                                                                  10,
                                                              strokeWidth: 10,
                                                              color: readyColor,
                                                            ),
                                                          ]),
                                                          Row(children: [
                                                            SettingActionButton.sized(
                                                                "SET STABILIZE",
                                                                (serialBusy)
                                                                    ? null
                                                                    : () =>
                                                                        setCurrentColorSchemeStabilize(),
                                                                widthColorButton,
                                                                0.0),
                                                            Placeholder(
                                                              fallbackWidth:
                                                                  100,
                                                              fallbackHeight:
                                                                  10,
                                                              strokeWidth: 10,
                                                              color:
                                                                  stabilizeColor,
                                                            ),
                                                          ]),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 50),
                                                      SizedBox(
                                                        height: 200,
                                                        width: 400,
                                                        child: MaterialPicker(
                                                          pickerColor:
                                                              pickerColor,
                                                          onColorChanged:
                                                              changeColor,
                                                          enableLabel: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 50),
                                                    ],
                                                  ),
                                                ),
                                                Stack(
                                                  children: [
                                                    SettingCard(
                                                      locked:
                                                          factorySettingsLockStabilizationFactor,
                                                      name: "Stabilization",
                                                      subtitle:
                                                          "How much stability is required to get a compass reading",
                                                      icon: Icons.vibration,
                                                      actionWidget: Row(
                                                        children: [
                                                          SettingActionButton(
                                                              "GET CURRENT",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentStabilizationFactor()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "LOW": 5,
                                                                "MID": 10,
                                                                "HIGH": 20
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setStabilizationFactor,
                                                              stabilizationFactor),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            factorySettingsLockStabilizationFactor =
                                                                !factorySettingsLockStabilizationFactor;
                                                          });
                                                        },
                                                        icon: factorySettingsLockStabilizationFactor
                                                            ? const Icon(
                                                                Icons.lock)
                                                            : const Icon(Icons
                                                                .lock_open)),
                                                  ],
                                                ),
                                                Stack(
                                                  children: [
                                                    SettingCard(
                                                      locked:
                                                          factorySettingsLockSlider,
                                                      name: "Slider Button",
                                                      subtitle:
                                                          "Adjust the sensitivity of the slider button",
                                                      icon: Icons.smart_button,
                                                      actionWidget: Row(
                                                        children: [
                                                          SettingActionButton(
                                                              "GET CURRENT",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentClickThreshold()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "LOW(50)": 50,
                                                                "MID(40)": 40,
                                                                "HIGH(30)": 30,
                                                                "ULTRA HIGH(25)":
                                                                    25,
                                                                "MK.SPEC II (20)":
                                                                    15,
                                                                "MK.SPEC I (15)":
                                                                    15
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setClickThreshold,
                                                              clickThreshold),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            factorySettingsLockSlider =
                                                                !factorySettingsLockSlider;
                                                          });
                                                        },
                                                        icon: factorySettingsLockSlider
                                                            ? const Icon(
                                                                Icons.lock)
                                                            : const Icon(Icons
                                                                .lock_open)),
                                                  ],
                                                ),
                                                Stack(
                                                  children: [
                                                    SettingCard(
                                                      locked:
                                                          factorySettingsLockBMDuration,
                                                      name: "Basic Mode",
                                                      subtitle:
                                                          "Adjust the duration required to validate a command with the slider button",
                                                      icon: Icons.smart_button,
                                                      actionWidget: Row(
                                                        children: [
                                                          SettingActionButton(
                                                              "GET CURRENT",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentBMClickDurationFactor()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "EXTRA FAST":
                                                                    25,
                                                                "FAST": 50,
                                                                "NORMAL": 100,
                                                                "SLOW": 150
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setBMDurationFactor,
                                                              clickBMDurationFactor),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            factorySettingsLockBMDuration =
                                                                !factorySettingsLockBMDuration;
                                                          });
                                                        },
                                                        icon: factorySettingsLockBMDuration
                                                            ? const Icon(
                                                                Icons.lock)
                                                            : const Icon(Icons
                                                                .lock_open)),
                                                  ],
                                                ),
                                                Stack(
                                                  children: [
                                                    SettingCard(
                                                      locked:
                                                          factorySettingsLockSafetyON,
                                                      name: "Switch ON Safety",
                                                      subtitle:
                                                          "Require to click right before switching on the device",
                                                      icon: Icons.smart_button,
                                                      actionWidget: Row(
                                                        children: [
                                                          SettingActionButton(
                                                              "GET CURRENT",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentsafetySwitchON()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "DISABLED": 0,
                                                                "ENABLED": 1
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setCurrentsafetySwitchON,
                                                              safetySwitchON),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            factorySettingsLockSafetyON =
                                                                !factorySettingsLockSafetyON;
                                                          });
                                                        },
                                                        icon: factorySettingsLockSafetyON
                                                            ? const Icon(
                                                                Icons.lock)
                                                            : const Icon(Icons
                                                                .lock_open)),
                                                  ],
                                                ),
                                                Stack(
                                                  children: [
                                                    SettingCard(
                                                      locked:
                                                          factorySettingsDoubleTapON,
                                                      name: "Double Tap",
                                                      subtitle:
                                                          "Double tap sensitivity to display the current survey",
                                                      icon: Icons.smart_button,
                                                      actionWidget: Row(
                                                        children: [
                                                          SettingActionButton(
                                                              "GET CURRENT",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentDoubleTap()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "DISABLED": 0,
                                                                "LIGHT": 15,
                                                                "NORMAL": 20,
                                                                "HARD": 28
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setCurrentDoubleTap,
                                                              doubleTap),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            factorySettingsDoubleTapON =
                                                                !factorySettingsDoubleTapON;
                                                          });
                                                        },
                                                        icon: factorySettingsDoubleTapON
                                                            ? const Icon(
                                                                Icons.lock)
                                                            : const Icon(Icons
                                                                .lock_open)),
                                                  ],
                                                ),
                                                Stack(
                                                  children: [
                                                    SettingCard(
                                                      locked:
                                                          factorySettingsLock,
                                                      name:
                                                          "Compass HW parameter",
                                                      subtitle:
                                                          "Set Compass Orientation (Factory Settings)",
                                                      icon: Icons.hardware,
                                                      actionWidget: Row(
                                                        children: [
                                                          SettingActionButton(
                                                              "GET X",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentXCompass()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "1": 1,
                                                                "-1": 255,
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setXCompass,
                                                              xCompass),
                                                          SettingActionButton(
                                                              "GET Y",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentYCompass()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "1": 1,
                                                                "-1": 255,
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setYCompass,
                                                              yCompass),
                                                          SettingActionButton(
                                                              "GET Z",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentZCompass()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "1": 1,
                                                                "-1": 255,
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setZCompass,
                                                              zCompass),
                                                          SettingActionButton(
                                                              "GET CAL. MODE",
                                                              (serialBusy)
                                                                  ? null
                                                                  : () =>
                                                                      getCurrentCalMode()),
                                                          SettingActionRadioList(
                                                              "SYNC NOW",
                                                              const {
                                                                "SLOW": 0,
                                                                "FAST": 1,
                                                              },
                                                              (serialBusy)
                                                                  ? null
                                                                  : setCalMode,
                                                              calMode),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            factorySettingsLock =
                                                                !factorySettingsLock;
                                                          });
                                                        },
                                                        icon: factorySettingsLock
                                                            ? const Icon(
                                                                Icons.lock)
                                                            : const Icon(Icons
                                                                .lock_open)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              //CLI ---------------------------------------------------
                              (!connected)
                                  ? Column(
                                      children: [
                                        const Text(
                                            "Connect the Mnemo to your computer and press the refresh button"),
                                        IconButton(
                                          onPressed: onRefreshMnemo,
                                          icon: const Icon(Icons.refresh),
                                          tooltip: "Search for Device",
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        AppBar(
                                          title: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(
                                                          20, 0, 0, 0),
                                                  child: TextFormField(
                                                    showCursor: true,
                                                    onFieldSubmitted: (serialBusy)
                                                        ? null
                                                        : onExecuteCLICommand,
                                                    autofocus: true,
                                                    obscureText: false,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText: "Command",
                                                      hintText:
                                                          '[Enter Command or type help]',
                                                      enabledBorder:
                                                          UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color:
                                                              Color(0x00000000),
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                  4.0),
                                                          topRight:
                                                              Radius.circular(
                                                                  4.0),
                                                        ),
                                                      ),
                                                      focusedBorder:
                                                          UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color:
                                                              Color(0x00000000),
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                  4.0),
                                                          topRight:
                                                              Radius.circular(
                                                                  4.0),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.white30,
                                        ),
                                        Expanded(
                                          child: Scaffold(
                                            backgroundColor: Colors.black,
                                            floatingActionButton:
                                                FloatingActionButton.small(
                                              onPressed: _scrollDown,
                                              child: const Icon(
                                                  Icons.arrow_downward),
                                            ),
                                            body: Container(
                                              decoration: const BoxDecoration(
                                                  color: Colors.black),
                                              child: ListView(
                                                controller: cliScrollController,
                                                padding:
                                                    const EdgeInsets.all(20),
                                                shrinkWrap: true,
                                                scrollDirection: Axis.vertical,
                                                children: cliHistory
                                                    .where((e) => e.length >= 2)
                                                    .map(
                                                      (e) => RichText(
                                                        text: TextSpan(
                                                          text: e.substring(2),
                                                          style: TextStyle(
                                                              color: (e.substring(
                                                                          0,
                                                                          2) ==
                                                                      "a:")
                                                                  ? Colors
                                                                      .white70
                                                                  : (e.substring(
                                                                              0,
                                                                              2) ==
                                                                          "c:")
                                                                      ? Colors
                                                                          .yellow
                                                                      : Colors
                                                                          .red,
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void onExecuteCLICommand(command) async {
    executeCLIAsync(command);
    if (!cliCommandHistory.contains(command)) {
      setState(() {
        cliCommandHistory.add(command);
      });
    }
  }

  void _scrollDown() {
    cliScrollController.animateTo(
      cliScrollController.position.maxScrollExtent,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 1000),
    );
  }

  Future<void> setZCompass(e) async {
    await executeCLIAsync("eepromwrite 34 $e");
    getCurrentZCompass();
  }

  Future<void> setCalMode(e) async {
    await executeCLIAsync("eepromwrite 37 $e");
    getCurrentCalMode();
  }

  Future<void> setYCompass(e) async {
    await executeCLIAsync("eepromwrite 33 $e");
    getCurrentYCompass();
  }

  Future<void> setXCompass(e) async {
    await executeCLIAsync("eepromwrite 32 $e");
    getCurrentXCompass();
  }

  Future<void> setClickThreshold(e) async {
    await executeCLIAsync("setclickthreshold $e");
    getCurrentClickThreshold();
  }

  Future<void> setBMDurationFactor(e) async {
    await executeCLIAsync("setBMclickfactor $e");
    getCurrentBMClickDurationFactor();
  }

  Future<void> setStabilizationFactor(e) async {
    await executeCLIAsync("setstabilizationfactor $e");
    await getCurrentStabilizationFactor();
  }

  Future<void> removeFromWifiList(e) async {
    await executeCLIAsync("removewifinet $e");
    await getCurrentWifiList();
  }

  Future<void> setCurrentsafetySwitchON(e) async {
    await executeCLIAsync("eepromwrite 57 $e");
    getCurrentsafetySwitchON();
  }

  Future<void> setCurrentDoubleTap(e) async {
    await executeCLIAsync("eepromwrite 56 $e");
    getCurrentDoubleTap();
  }

  Future<void> setTimeFormat(e) async {
    await executeCLIAsync("eepromwrite 35 $e");
    getCurrentTimeFormat();
  }

  Future<void> setDateFormat(e) async {
    await executeCLIAsync("eepromwrite 36 $e");
    getCurrentDateFormat();
  }

  Future<void> executeCLIAsync(String rawCommand) async {
    setState(() => serialBusy = true);
    var res = mnemoPort.openReadWrite();
    mnemoPort.flush();

    if (res == false) {
      setState(() {
        cliHistory.add("e:Error Opening Port");
        serialBusy = false;
        connected = false;
      });
      return;
    }
    var command = rawCommand.trim();
    var commandnl = '$command\n';

    var uint8list = Uint8List.fromList(
        utf8.decode(commandnl.runes.toList()).runes.toList());
    int? nbwritten = mnemoPort.write(uint8list, timeout: 1000);

    setState(() => cliHistory.add(
        (nbwritten == commandnl.length) ? "c:$command" : "e:Error $command"));

    String commandnoPara = "";
    if (command.contains(" ")) {
      commandnoPara = command.split(" ").first.trim();
    } else {
      commandnoPara = command;
    }

    switch (commandnoPara) {
      case "getdata":
        sections.getSections().clear();
        await waitAnswerAsync();
        commandSent = true;
        mnemoPort.close();

        break;

      case "syncdatetime":
        var startCodeInt = List<int>.empty(growable: true);

        var date = DateTime.now();

        startCodeInt.add(date.year % 100);
        startCodeInt.add(date.month);
        startCodeInt.add(date.day);
        startCodeInt.add(date.hour);
        startCodeInt.add(date.minute);
        var uint8list2 = Uint8List.fromList(startCodeInt);
        int? nbwritten = mnemoPort.write(uint8list2);
        setState(() => cliHistory
            .add((nbwritten == 5) ? "a:DateTime$date" : "e:Error in DateTime"));

        commandSent = true;
        mnemoPort.close();
        break;

      case "readfile":
        await waitAnswerAsync();
        await saveFile();
        commandSent = true;
        mnemoPort.close();
        break;

      default:
        await waitAnswerAsync();
        if (transferBuffer.isNotEmpty) displayAnswer();
        commandSent = true;
        mnemoPort.close();

        break;
    }
    setState(() => serialBusy = false);
  }

  Future<void> waitAnswerAsync() async {
    int counterWait = 0;
    transferBuffer.clear();
    final mnemoPort = this.mnemoPort;

    while (counterWait == 0) {
      while (mnemoPort.bytesAvailable <= 0) {
        await Future.delayed(const Duration(milliseconds: 20));

        counterWait++;
        if (counterWait == 100) {
          //  initMnemoPort();
          break;
        }
      }
      if (counterWait == 100) {
        // initMnemoPort();
        break;
      }

      counterWait = 0;

      var readBuffer8 = mnemoPort.read(mnemoPort.bytesAvailable, timeout: 5000);
      for (int i = 0; i < readBuffer8.length; i++) {
        transferBuffer.add(readBuffer8[i]);
      }

      //Check if ending with transmissionovermessage
      if (utf8
          .decode(transferBuffer, allowMalformed: true)
          .contains("MN2Over")) {
        var lengthBuff = transferBuffer.length;
        transferBuffer.removeRange(lengthBuff - 7, lengthBuff);
        return;
      }
    }
  }

  void displayAnswer() {
    setState(() => cliHistory.add("a:${utf8.decode(transferBuffer).trim()}"));
  }

  Future<void> onSaveDMP() async {
// Lets the enter file name, only files with the corresponding extensions are displayed
    var result = await FilePicker.platform.saveFile(
        dialogTitle: "Save as DMP",
        type: FileType.custom,
        allowedExtensions: ["dmp"]);

// The result will be null, if the user aborted the dialog
    if (result != null) {
      if (!result.toLowerCase().endsWith('.dmp')) result += ".dmp";
      File file = File(result);
      var sink = file.openWrite();
      for (var element in transferBuffer) {
        (element >= 0 && element <= 127)
            ? sink.write("$element;")
            : sink.write("${-(256 - element)};");
      }

      await sink.flush();
      await sink.close();
    }
  }

  Future<void> onExportSVX() async {
    var result = await FilePicker.platform.saveFile(
        dialogTitle: "Save as Survex",
        type: FileType.custom,
        allowedExtensions: ["svx"]);

    if (result != null) {
      if (!result.toLowerCase().endsWith('.svx')) result += ".svx";

      final exporter = SurvexExporter();
      await exporter.export(sections, result, unitType);
    }
  }

  Future<void> onExportTH() async {
    var result = await FilePicker.platform.saveFile(
        dialogTitle: "Save as Therion (.th)",
        type: FileType.custom,
        allowedExtensions: ["th"]);

    if (result != null) {
      if (!result.toLowerCase().endsWith('.th')) result += ".th";

      final exporter = THExporter();
      await exporter.export(sections, result, unitType);
    }
  }

  Future<void> onExportXLS() async {
    // Lets the user pick one file; files with any file extension can be selected
    var result = await FilePicker.platform.saveFile(
        dialogTitle: "Save as Excel",
        type: FileType.custom,
        allowedExtensions: ["xlsx"]);

// The result will be null, if the user aborted the dialog
    if (result != null) {
      if (!result.toLowerCase().endsWith('.xlsx')) result += ".xlsx";

      File file = File(result);
      exportAsExcel(sections, file, unitType);
    }
  }

  Future<void> getCurrentName() async {
    await executeCLIAsync("getname");
    nameDevice = utf8.decode(transferBuffer).trim();
  }

  Future<void> onSyncDateTime() async {
    await executeCLIAsync("syncdatetime");
  }

  Future<void> getCurrentStabilizationFactor() async {
    await executeCLIAsync("getstabilizationfactor");
    var decode = utf8.decode(transferBuffer);
    stabilizationFactor = int.parse(decode);
  }

  Future<void> getCurrentClickThreshold() async {
    await executeCLIAsync("getclickthreshold");
    var decode = utf8.decode(transferBuffer);
    clickThreshold = int.parse(decode);
  }

  Future<void> getCurrentBMClickDurationFactor() async {
    await executeCLIAsync("getBMclickfactor");
    var decode = utf8.decode(transferBuffer);
    clickBMDurationFactor = int.parse(decode);
  }

  Future<void> getCurrentsafetySwitchON() async {
    await executeCLIAsync("eepromread 57");
    var decode = utf8.decode(transferBuffer);
    safetySwitchON = int.parse(decode);
  }

  Future<void> getCurrentDoubleTap() async {
    await executeCLIAsync("eepromread 56");
    var decode = utf8.decode(transferBuffer);
    doubleTap = int.parse(decode);
  }

  Future<void> getCurrentWifiList() async {
    await executeCLIAsync("listwifinet");
    var decode = utf8.decode(transferBuffer);
    wifiList = decode.split(("\r\n"));
    wifiList.removeWhere((element) => element.isEmpty);
  }

  Future<void> addToWifiList(String name, String passwd) async {
    await executeCLIAsync("addwifinet $name $passwd");
    await getCurrentWifiList();
  }

  Future<void> getCurrentXCompass() async {
    await executeCLIAsync("eepromread 32");
    var decode = utf8.decode(transferBuffer);
    xCompass = int.parse(decode);
  }

  Future<void> getCurrentYCompass() async {
    await executeCLIAsync("eepromread 33");
    var decode = utf8.decode(transferBuffer);
    yCompass = int.parse(decode);
  }

  Future<void> getCurrentZCompass() async {
    await executeCLIAsync("eepromread 34");
    var decode = utf8.decode(transferBuffer);
    zCompass = int.parse(decode);
  }

  Future<void> getCurrentCalMode() async {
    await executeCLIAsync("eepromread 37");
    var decode = utf8.decode(transferBuffer);
    calMode = int.parse(decode);
  }

  Future<void> getCurrentTimeFormat() async {
    await executeCLIAsync("eepromread 35");
    var decode = utf8.decode(transferBuffer);
    timeFormat = int.parse(decode);
  }

  Future<void> getCurrentDateFormat() async {
    await executeCLIAsync("eepromread 36");
    var decode = utf8.decode(transferBuffer);
    dateFormat = int.parse(decode);
  }

  Future<void> saveFile() async {
    // Lets the user pick one file; files with any file extension can be selected
    var result = await FilePicker.platform.saveFile(dialogTitle: "Save File");

// The result will be null, if the user aborted the dialog
    if (result != null) {
      File file = File(result);
      var sink = file.openWrite();

      sink.add(transferBuffer);

      await sink.flush();
      await sink.close();
    }
  }

  Future<void> getCurrentColorScheme() async {
    await executeCLIAsync("getcolor readinga");
    var decode = utf8.decode(transferBuffer);
    setState(() => readingAColor = Color(0xFF000000 + int.parse(decode)));

    await executeCLIAsync("getcolor readingb");
    decode = utf8.decode(transferBuffer);
    setState(() => readingBColor = Color(0xFF000000 + int.parse(decode)));

    await executeCLIAsync("getcolor standby");
    decode = utf8.decode(transferBuffer);
    setState(() => standbyColor = Color(0xFF000000 + int.parse(decode)));

    await executeCLIAsync("getcolor ready");
    decode = utf8.decode(transferBuffer);
    setState(() => readyColor = Color(0xFF000000 + int.parse(decode)));

    await executeCLIAsync("getcolor stabilize");
    decode = utf8.decode(transferBuffer);
    setState(() => stabilizeColor = Color(0xFF000000 + int.parse(decode)));
  }

  Future<void> setCurrentColorSchemeReadingA() async {
    setState(() => readingAColor = pickerColor);
    await executeCLIAsync("setcolor readinga ${pickerColor.value.toString()}");
  }

  Future<void> setCurrentColorSchemeReadingB() async {
    setState(() => readingBColor = pickerColor);
    await executeCLIAsync("setcolor readingb ${pickerColor.value.toString()}");
  }

  Future<void> setCurrentColorSchemeReady() async {
    setState(() => readyColor = pickerColor);
    await executeCLIAsync("setcolor ready ${pickerColor.value.toString()}");
  }

  Future<void> setCurrentColorSchemeStabilize() async {
    setState(() => stabilizeColor = pickerColor);
    await executeCLIAsync("setcolor stabilize ${pickerColor.value.toString()}");
  }

  Future<void> setCurrentColorSchemeStandBy() async {
    setState(() => standbyColor = pickerColor);
    await executeCLIAsync("setcolor standby ${pickerColor.value.toString()}");
  }

  Future<void> resetColorScheme() async {
    await executeCLIAsync("defaultcolorscheme");
    await getCurrentColorScheme();
  }

  Future<void> getTimeON() async {
    await executeCLIAsync("gettimeon");
    timeON = int.parse(utf8.decode(transferBuffer).trim());
  }

  Future<void> getTimeSurvey() async {
    await executeCLIAsync("gettimesurvey");
    timeSurvey = int.parse(utf8.decode(transferBuffer).trim());
  }

  Future<void> getDeviceFirmware() async {
    await executeCLIAsync("getfirmwareversion");
    var result = utf8.decode(transferBuffer).trim();
    var splits = result.split('.');
    var splitsplus = splits[2].split('+');
    setState(() {
      firmwareVersionMajor = int.parse(splits[0]);
      firmwareVersionMinor = int.parse(splits[1]);
      firmwareVersionRevision = int.parse(splitsplus[0]);
      firmwareVersionBuild = int.parse(splitsplus[1]);
    });
  }
}

extension IntToString on int {
  String toHex() => '0x${toRadixString(16)}';

  String toPadded([int width = 3]) => toString().padLeft(width, '0');

  String toTransport() {
    switch (this) {
      case SerialPortTransport.usb:
        return 'USB';
      case SerialPortTransport.bluetooth:
        return 'Bluetooth';
      case SerialPortTransport.native:
        return 'Native';
      default:
        return 'Unknown';
    }
  }
}
