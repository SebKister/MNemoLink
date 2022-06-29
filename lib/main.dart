import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:mnemolink/excelexport.dart';
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
      title: 'Flutter Demo',
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
  SerialPort? mnemoPort;
  bool connected = false;
  List<String> CLIHistory = [""];
  var transferBuffer = List<int>.empty(growable: true);
  SectionList sections =  SectionList();
  var cliScrollController =  ScrollController();
  bool commandSent = false;
  UnitType unitType = UnitType.METRIC;
  int stabilizationFactor = 0;
  int clickThreshold = 30;
  List<String> wifiList = [];

  int xCompass = 0;
  int yCompass = 0;
  int zCompass = 0;

  bool factorySettingsLock = true;

  var factorySettingsLockSlider = true;

  @override
  void initState() {
    super.initState();
    initMnemoPort();

    cliScrollController.addListener(() {
      if (cliScrollController.hasClients && commandSent) {
        final position = cliScrollController.position.maxScrollExtent;
        cliScrollController.jumpTo(position);
        commandSent = false;
      }
    });
  }

  String getMnemoAddress() {
    return SerialPort.availablePorts.firstWhere(
        (element) => SerialPort(element).productName == "Nano RP2040 Connect",
        orElse: () => "");
  }

  void initMnemoPort() {
    setState(() {
      mnemoPortAddress = getMnemoAddress();
      if (mnemoPortAddress == "") {
        connected = false;
      } else {
        mnemoPort = SerialPort(mnemoPortAddress);
        connected = true;
      }
    });
  }

  void onReadData() {
    executeCLI("getdata");
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
      Section section =  Section();

      int fileVersion = 0;

      while (fileVersion != 2) {
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
      StringBuffer stbuilder =  StringBuffer();
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
        shot =  Shot.zero();
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

        shot.setMarkerIndex(readByteFromEEProm(cursor++));

        section.getShots().add(shot);
      } while (shot.getTypeShot() != TypeShot.EOC);

      setState(() {
        sections.getSections().add(section);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: connected
                  ? [
                      Column(
                        children: [
                          Text("MNemo Connected on $mnemoPortAddress"),
                          Text(
                              style: const TextStyle(fontSize: 12),
                              ' SN ${mnemoPort?.serialNumber}')
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
                  child: Text("Click on connect"),
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
                                      onPressed: onReadData,
                                      icon: const Icon(Icons.refresh),
                                      tooltip: "Read Data from Device",
                                    ),
                                    IconButton(
                                      onPressed: onSaveDMP,
                                      icon: const Icon(Icons.save),
                                      tooltip: "Save as DMP",
                                    ),
                                    IconButton(
                                      onPressed: onExportXLS,
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
                                            (e) => Card(
                                              child: ListTile(
                                                title: Text(e.name),
                                                subtitle:
                                                    Text("#${e.shots.length}"),
                                                trailing: Text(
                                                    DateFormat('yyyy-MM-dd')
                                                        .format(e.dateSurey)),
                                              ),
                                            ),
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
                                            actionWidget: SettingActionButton(
                                                "SYNC NOW",
                                                () =>
                                                    executeCLI("syncdatetime")),
                                          ),
                                          SettingCard(
                                            name: "Stabilization",
                                            subtitle:
                                                "How much stability is required to get a compass reading",
                                            icon: Icons.vibration,
                                            actionWidget: Row(
                                              children: [
                                                SettingActionButton(
                                                    "GET CURRENT",
                                                    () =>
                                                        getCurrentStabilizationFactor()),
                                                SettingActionRadioList(
                                                    "SYNC NOW", {
                                                  "LOW": 50,
                                                  "MID": 100,
                                                  "HIGH": 220
                                                }, (e) {
                                                  executeCLI(
                                                      "setstabilizationfactor $e");
                                                  getCurrentStabilizationFactor();
                                                }, stabilizationFactor),
                                              ],
                                            ),
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
                                                    () => getCurrentWifiList()),
                                                SettingWifiList(wifiList, (e) {
                                                  executeCLI(
                                                      "removewifinet $e");
                                                  getCurrentWifiList();
                                                }),
                                                SettingWifiActionButton(
                                                    "ADD NEW",
                                                    (e, f) =>
                                                        addToWifiList(e, f)),
                                              ],
                                            ),
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
                                                        () =>
                                                            getCurrentClickThreshold()),
                                                    SettingActionRadioList(
                                                        "SYNC NOW", {
                                                      "LOW": 50,
                                                      "MID": 40,
                                                      "HIGH": 35
                                                    }, (e) {
                                                      executeCLI(
                                                          "setclickthreshold $e");
                                                      getCurrentClickThreshold();
                                                    }, clickThreshold),
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
                                                          ? const Icon(Icons.lock)
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
                                                        () =>
                                                            getCurrentXCompass()),
                                                    SettingActionRadioList(
                                                        "SYNC NOW", {
                                                      "1": 1,
                                                      "-1": 255,
                                                    }, (e) {
                                                      executeCLI(
                                                          "eepromwrite 32 $e");
                                                      getCurrentXCompass();
                                                    }, xCompass),
                                                    SettingActionButton(
                                                        "GET Y",
                                                        () =>
                                                            getCurrentYCompass()),
                                                    SettingActionRadioList(
                                                        "SYNC NOW", {
                                                      "1": 1,
                                                      "-1": 255,
                                                    }, (e) {
                                                      executeCLI(
                                                          "eepromwrite 33 $e");
                                                      getCurrentYCompass();
                                                    }, yCompass),
                                                    SettingActionButton(
                                                        "GET Z",
                                                        () =>
                                                            getCurrentZCompass()),
                                                    SettingActionRadioList(
                                                        "SYNC NOW", {
                                                      "1": 1,
                                                      "-1": 255,
                                                    }, (e) {
                                                      executeCLI(
                                                          "eepromwrite 34 $e");
                                                      getCurrentZCompass();
                                                    }, zCompass),
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
                                                      : const Icon(Icons.lock_open)),
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
                                                onFieldSubmitted:
                                                    (command) async {
                                                  executeCLI(command);
                                                },
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

      floatingActionButton: FloatingActionButton(
        onPressed: (connected) ? null : initMnemoPort,
        tooltip: 'Connect to the Mnemo',
        child: const Icon(Icons.connect_without_contact),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void executeCLI(String rawCommand) {
    mnemoPort?.openReadWrite();

    var command = rawCommand.trim();
    var commandnl = '$command\n';

    var uint8list = Uint8List.fromList(
        utf8.decode(commandnl.runes.toList()).runes.toList());
    int? nbwritten = mnemoPort?.write(uint8list);

    setState(() => CLIHistory.add(
        (nbwritten == commandnl.length) ? command : "Error $command"));

    switch (command) {
      case "getdata":
        sections.getSections().clear();
        waitAnswer();
        analyzeTransferBuffer();
        commandSent = true;
        mnemoPort?.close();

        break;

      case "syncdatetime":
        var startCodeInt = List<int>.empty(growable: true);

        var date = DateTime.now();

        startCodeInt.add(date.year % 1000);
        startCodeInt.add(date.month);
        startCodeInt.add(date.day);
        startCodeInt.add(date.hour);
        startCodeInt.add(date.minute);
        var uint8list2 = Uint8List.fromList(startCodeInt);
        int? nbwritten = mnemoPort?.write(uint8list2);
        setState(() => CLIHistory.add(
            (nbwritten == 5) ? "DateTime$date\n" : "Error in DateTime\n"));

        commandSent = true;
        mnemoPort?.close();
        break;

      default:
        waitAnswer();
        if (transferBuffer.isNotEmpty) displayAnswer();
        commandSent = true;
        mnemoPort?.close();

        break;
    }
  }

  void waitAnswer() {
    int counterWait = 0;
    transferBuffer.clear();
    final mnemoPort = this.mnemoPort;

    while (counterWait == 0) {
      while (mnemoPort != null && mnemoPort.bytesAvailable <= 0) {
        sleep(const Duration(milliseconds: 20));

        counterWait++;
        if (counterWait == 100) {
          break;
        }
      }
      if (counterWait == 100) {
        break;
      }

      counterWait = 0;

      if (mnemoPort != null) {
        var readBuffer8 = mnemoPort.read(mnemoPort.bytesAvailable);
        for (int i = 0; i < readBuffer8.length; i++) {
          transferBuffer.add(readBuffer8[i]);
        }
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

  void onSyncDateTime() {
    executeCLI("syncdatetime");
  }

  void getCurrentStabilizationFactor() {
    executeCLI("getstabilizationfactor");
    var decode = utf8.decode(transferBuffer);
    stabilizationFactor = int.parse(decode);
  }

  void getCurrentClickThreshold() {
    executeCLI("getclickthreshold");
    var decode = utf8.decode(transferBuffer);
    clickThreshold = int.parse(decode);
  }

  void getCurrentWifiList() {
    executeCLI("listwifinet");
    var decode = utf8.decode(transferBuffer);
    wifiList = decode.split(("\r\n"));
    wifiList.removeWhere((element) => element.isEmpty);
  }

  addToWifiList(String name, String passwd) {
    executeCLI("addwifinet $name $passwd");
    getCurrentWifiList();
  }

  getCurrentXCompass() {
    executeCLI("eepromread 32");
    var decode = utf8.decode(transferBuffer);
    xCompass = int.parse(decode);
  }

  getCurrentYCompass() {
    executeCLI("eepromread 33");
    var decode = utf8.decode(transferBuffer);
    yCompass = int.parse(decode);
  }

  getCurrentZCompass() {
    executeCLI("eepromread 34");
    var decode = utf8.decode(transferBuffer);
    zCompass = int.parse(decode);
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
