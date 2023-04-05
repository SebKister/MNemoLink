import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mnemolink/excelexport.dart';
import 'package:mnemolink/sectioncard.dart';
import 'package:mnemolink/settingcard.dart';

import 'dart:convert' show utf8;
import './section.dart';
import './shot.dart';
import './sectionlist.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNemo Link',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'MNemo Link'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String mnemoPortAddress = "";
  late SerialPort mnemoPort;
  bool connected = false;
  List<String> CLIHistory = [""];
  var transferBuffer = List<int>.empty(growable: true);
  SectionList sections = SectionList();
  var cliScrollController = ScrollController();
  bool commandSent = false;
  UnitType unitType = UnitType.METRIC;
  int stabilizationFactor = 0;
  String nameDevice = "";
  int clickThreshold = 30;
  int clickBMDurationFactor = 100;
  int safetySwitchON = -1;
  int doubleTap = -1;
  List<String> wifiList = [];
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

// create some values
  Color pickerColor = Color(0xff443a49);
  Color readingAColor = Color(0x00000000);
  Color readingBColor = Color(0x00000000);
  Color standbyColor = Color(0x00000000);
  Color stabilizeColor = Color(0x00000000);
  Color readyColor = Color(0x00000000);

// ValueChanged<Color> callback
  void changeColor(Color color) {
    setState(() => pickerColor = color);
  }

  int xCompass = 0;
  int yCompass = 0;
  int zCompass = 0;
  int calMode = -1;

  bool factorySettingsLockSafetyON = true;

  bool factorySettingsLock = true;

  var factorySettingsLockSlider = true;

  bool factorySettingsLockBMDuration = true;

  bool factorySettingsLockStabilizationFactor = true;

  bool factorySettingsDoubleTapON = true;

  bool serialBusy = false;

  int dateFormat = -1;

  int timeFormat = -1;

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  void initState() {
    super.initState();

    cliScrollController.addListener(() {
      if (cliScrollController.hasClients && commandSent) {
        final position = cliScrollController.position.maxScrollExtent;
        cliScrollController.jumpTo(position);
        commandSent = false;
      }
    });
/*
    FlutterWindowClose.setWindowShouldCloseHandler(() async {
    return await (){  if (mnemoPort != null &&
          mnemoPort.isOpen != null &&
          mnemoPort.isOpen == true) {
        mnemoPort.flush();
        mnemoPort.close();
      }
      return true;}();
    });
*/
    _initPackageInfo();
    initMnemoPort();
  }

  String getMnemoAddress() {
    return SerialPort.availablePorts.firstWhere(
        (element) => SerialPort(element).productName == "Nano RP2040 Connect",
        orElse: () => "");
  }

  Future<void> initMnemoPort() async {
    setState(() {
      mnemoPortAddress = getMnemoAddress();
      if (mnemoPortAddress == "") {
        connected = false;
      } else {
        mnemoPort = SerialPort(mnemoPortAddress);
        connected = mnemoPort.openReadWrite();
        mnemoPort.flush();
        mnemoPort.config.setFlowControl(0);
        mnemoPort.close();
        getCurrentName();
      }
    });
  }

  void onReadData() {
    executeCLIAsync("getdata");
  }

  int readByteFromEEProm(int adresse) {
    return transferBuffer.elementAt(adresse);
  }

  int readIntFromEEProm(int adresse) {
    final bytes = Uint8List.fromList(
        [transferBuffer[adresse], transferBuffer[adresse + 1]]);
    final byteData = ByteData.sublistView(bytes);
    return byteData.getInt16(0);
  }

  void analyzeTransferBuffer() {
    int currentMemory = transferBuffer.length;
    int cursor = 0;

    while (cursor < currentMemory - 2) {
      Section section = Section();

      int fileVersion = 0;

      while (fileVersion != 2 && fileVersion != 3) {
        fileVersion = readByteFromEEProm(cursor);
        cursor++;
      }
      int year = 0;

      while (year != 16 &&
          year != 17 &&
          year != 18 &&
          year != 19 &&
          year != 20 &&
          year != 21 &&
          year != 22 &&
          year != 23) {
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
      section.setDateSurey(dateSection);
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
      if (unitType == UnitType.METRIC) {
        conversionFactor = 1.0;
      } else {
        conversionFactor = 3.28084;
      }

      Shot shot;
      do {
        shot = Shot.zero();
        int typeShot = 0;

        typeShot = readByteFromEEProm(cursor++);

        if (typeShot > 3 || typeShot < 0) {
          break;
        }

        shot.setTypeShot(TypeShot.values[typeShot]);
        // cursor++;
        shot.setHeadingIn(readIntFromEEProm(cursor));
        cursor = cursor + 2;

        shot.setHeadingOut(readIntFromEEProm(cursor));
        cursor = cursor + 2;

        shot.setLength(readIntFromEEProm(cursor) * conversionFactor / 100.0);
        cursor = cursor + 2;

        shot.setDepthIn(readIntFromEEProm(cursor) * conversionFactor / 100.0);
        cursor = cursor + 2;

        shot.setDepthOut(readIntFromEEProm(cursor) * conversionFactor / 100.0);
        cursor = cursor + 2;

        shot.setPitchIn(readIntFromEEProm(cursor));
        cursor = cursor + 2;

        shot.setPitchOut(readIntFromEEProm(cursor));
        cursor = cursor + 2;
        if (fileVersion >= 3) {
          shot.setTemperature(readIntFromEEProm(cursor));
          cursor = cursor + 2;
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

        section.getShots().add(shot);
      } while (shot.getTypeShot() != TypeShot.EOC);

      setState(() {
        // Adding section only if it contains data. Note : EOC shot should always be present at end of section.
        if (section.shots.length > 1) ;
        sections.getSections().add(section);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double widthColorButton = 150.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(style: const TextStyle(fontSize: 12), _packageInfo.version)
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: connected
                  ? [
                      (serialBusy)
                          ? Container(
                              padding: const EdgeInsets.only(right: 30),
                              child: LoadingAnimationWidget.inkDrop(
                                  color: Colors.white60, size: 20),
                            )
                          : const SizedBox.shrink(),
                      Column(
                        children: [
                          Text("[$nameDevice] Connected on $mnemoPortAddress"),
                          Text(
                              style: const TextStyle(fontSize: 12),
                              ' SN ${mnemoPort.serialNumber}')
                        ],
                      )
                    ]
                  : [const Text("Mnemo Not detected")],
            ),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment:
            (!connected) ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: (!connected)
            ? <Widget>[
                const Center(
                  child: Text(
                      "Connect the Mnemo to your computer and restart the application"),
                ),
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
                              Column(children: [
                                AppBar(
                                  actions: [
                                    IconButton(
                                      onPressed:
                                          (serialBusy) ? null : onReadData,
                                      icon: const Icon(Icons.refresh),
                                      tooltip: "Read Data from Device",
                                    ),
                                    IconButton(
                                      onPressed:
                                          (serialBusy) ? null : onSaveDMP,
                                      icon: const Icon(Icons.save),
                                      tooltip: "Save as DMP",
                                    ),
                                    IconButton(
                                      onPressed:
                                          (serialBusy) ? null : onExportXLS,
                                      icon: const Icon(Icons.save_alt),
                                      tooltip: "Export as XLS",
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
                              Column(
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
                                                      : () => onSyncDateTime()),
                                              SettingActionButton(
                                                  "GET TIME FORMAT",
                                                  (serialBusy)
                                                      ? null
                                                      : () =>
                                                          getCurrentTimeFormat()),
                                              SettingActionRadioList(
                                                  "",
                                                  {
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
                                                  {
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
                                                  MainAxisAlignment.spaceEvenly,
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
                                            icon: Icons.color_lens_outlined,
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
                                                        fallbackWidth: 100,
                                                        fallbackHeight: 10,
                                                        strokeWidth: 10,
                                                        color: readingAColor,
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
                                                        fallbackWidth: 100,
                                                        fallbackHeight: 10,
                                                        strokeWidth: 10,
                                                        color: readingBColor,
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
                                                        fallbackWidth: 100,
                                                        fallbackHeight: 10,
                                                        strokeWidth: 10,
                                                        color: standbyColor,
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
                                                        fallbackWidth: 100,
                                                        fallbackHeight: 10,
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
                                                        fallbackWidth: 100,
                                                        fallbackHeight: 10,
                                                        strokeWidth: 10,
                                                        color: stabilizeColor,
                                                      ),
                                                    ]),
                                                  ],
                                                ),
                                                SizedBox(width: 50),
                                                SizedBox(
                                                  height: 200,
                                                  child: MaterialPicker(
                                                    pickerColor: pickerColor,
                                                    onColorChanged: changeColor,
                                                    enableLabel: true,
                                                  ),
                                                ),
                                                SizedBox(width: 50),
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
                                                        {
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
                                                  icon:
                                                      factorySettingsLockStabilizationFactor
                                                          ? const Icon(
                                                              Icons.lock)
                                                          : const Icon(
                                                              Icons.lock_open)),
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
                                                        {
                                                          "LOW": 50,
                                                          "MID": 40,
                                                          "HIGH": 30,
                                                          "ULTRA HIGH": 25
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
                                                  icon:
                                                      factorySettingsLockSlider
                                                          ? const Icon(
                                                              Icons.lock)
                                                          : const Icon(
                                                              Icons.lock_open)),
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
                                                        {
                                                          "EXTRA FAST": 25,
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
                                                  icon:
                                                      factorySettingsLockBMDuration
                                                          ? const Icon(
                                                              Icons.lock)
                                                          : const Icon(
                                                              Icons.lock_open)),
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
                                                        {
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
                                                  icon:
                                                      factorySettingsLockSafetyON
                                                          ? const Icon(
                                                              Icons.lock)
                                                          : const Icon(
                                                              Icons.lock_open)),
                                            ],
                                          ),
                                          Stack(
                                            children: [
                                              SettingCard(
                                                locked:
                                                    factorySettingsDoubleTapON,
                                                name: "Double Tap",
                                                subtitle:
                                                    "Double tap the Mnemo to display the current survey",
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
                                                        {
                                                          "DISABLED": 0,
                                                          "ENABLED": 1
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
                                                  icon:
                                                      factorySettingsDoubleTapON
                                                          ? const Icon(
                                                              Icons.lock)
                                                          : const Icon(
                                                              Icons.lock_open)),
                                            ],
                                          ),
                                          Stack(
                                            children: [
                                              SettingCard(
                                                locked: factorySettingsLock,
                                                name: "Compass HW parameter",
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
                                                        {
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
                                                        {
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
                                                        {
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
                                                        {
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
                                                      ? const Icon(Icons.lock)
                                                      : const Icon(
                                                          Icons.lock_open)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              //CLI ---------------------------------------------------
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Column(
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
                                                      .fromSTEB(20, 0, 0, 0),
                                              child: TextFormField(
                                                onFieldSubmitted: (serialBusy)
                                                    ? null
                                                    : onExecuteCLICommand,
                                                autofocus: true,
                                                obscureText: false,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: "Command",
                                                  hintText:
                                                      '[Enter Command or type listcommands]',
                                                  enabledBorder:
                                                      UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
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
                                      child: Container(
                                        decoration: const BoxDecoration(
                                            color: Colors.black26),
                                        child: ListView(
                                          controller: cliScrollController,
                                          padding: const EdgeInsets.all(20),
                                          shrinkWrap: true,
                                          scrollDirection: Axis.vertical,
                                          children: CLIHistory.map(
                                            (e) => Card(
                                              child: ListTile(
                                                title: Text(e),
                                              ),
                                            ),
                                          ).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
        CLIHistory.add("Error Opening Port");
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

    setState(() => CLIHistory.add(
        (nbwritten == commandnl.length) ? command : "Error $command"));

    String commandnoPara = "";
    if (command.contains(" "))
      commandnoPara = command.split(" ").first.trim();
    else
      commandnoPara = command;

    switch (commandnoPara) {
      case "getdata":
        sections.getSections().clear();
        await waitAnswerAsync();
        analyzeTransferBuffer();
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
        setState(() => CLIHistory.add(
            (nbwritten == 5) ? "DateTime$date\n" : "Error in DateTime\n"));

        commandSent = true;
        mnemoPort.close();
        break;
      case "readfile":
        await waitAnswerAsync();
        await saveFile();

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
      while (mnemoPort != null && mnemoPort.bytesAvailable <= 0) {
        await Future.delayed(Duration(milliseconds: 20));

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

      if (mnemoPort != null) {
        var readBuffer8 =
            mnemoPort.read(mnemoPort.bytesAvailable, timeout: 5000);
        for (int i = 0; i < readBuffer8.length; i++) {
          transferBuffer.add(readBuffer8[i]);
        }
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
    setState(() => CLIHistory.add(utf8.decode(transferBuffer)));
  }

  Future<void> onSaveDMP() async {
// Lets the user pick one file; files with any file extension can be selected
    var result = await FilePicker.platform.saveFile(dialogTitle: "Save as DMP");

// The result will be null, if the user aborted the dialog
    if (result != null) {
      File file = File(result);
      if (!result.toLowerCase().endsWith('.dmp')) result += ".dmp";
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

  Future<void> onExportXLS() async {
    // Lets the user pick one file; files with any file extension can be selected
    var result = await FilePicker.platform.saveFile(dialogTitle: "Save as DMP");

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
    await executeCLIAsync("setcolor readinga " + pickerColor.value.toString());
  }

  Future<void> setCurrentColorSchemeReadingB() async {
    setState(() => readingBColor = pickerColor);
    await executeCLIAsync("setcolor readingb " + pickerColor.value.toString());
  }

  Future<void> setCurrentColorSchemeReady() async {
    setState(() => readyColor = pickerColor);
    await executeCLIAsync("setcolor ready " + pickerColor.value.toString());
  }

  Future<void> setCurrentColorSchemeStabilize() async {
    setState(() => stabilizeColor = pickerColor);
    await executeCLIAsync("setcolor stabilize " + pickerColor.value.toString());
  }

  Future<void> setCurrentColorSchemeStandBy() async {
    setState(() => standbyColor = pickerColor);
    await executeCLIAsync("setcolor standby " + pickerColor.value.toString());
  }

  Future<void> resetColorScheme() async {
    await executeCLIAsync("defaultcolorscheme");
    await getCurrentColorScheme();
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
