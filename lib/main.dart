import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import "./cardlisttile.dart";
import 'dart:convert' show utf8;

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
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'MNemo Link'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String mnemoPortAddress = "";
  SerialPort? mnemoPort;
  bool connected = false;
  String CLIHistory = "";
  var transferBuffer = List<int>.empty(growable: true);

  @override
  void initState() {
    super.initState();
    initMnemoPort();
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

  void onReadData() {}

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Column(
        // Column is also a layout widget. It takes a list of children and
        // arranges them vertically. By default, it sizes itself to fit its
        // children horizontally, and tries to be as tall as its parent.
        //
        // Invoke "debug painting" (press "p" in the console, choose the
        // "Toggle Debug Paint" action from the Flutter Inspector in Android
        // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
        // to see the wireframe for each widget.
        //
        // Column has various properties to control how it sizes itself and
        // how it positions its children. Here we use mainAxisAlignment to
        // center the children vertically; the main axis here is the vertical
        // axis because Columns are vertical (the cross axis would be
        // horizontal).
        mainAxisAlignment: MainAxisAlignment.start,
        children: (!connected)
            ? <Widget>[const Text("Click on connect")]
            : <Widget>[
                ExpansionTile(
                    title: Text("MNemo Connected on $mnemoPortAddress"),
                    children: [
                      CardListTile('Serial Number', mnemoPort?.serialNumber),
                    ]),
                ExpansionTile(
                    title: Row(children: <Widget>[
                      const Text("Data"),
                      IconButton(
                          onPressed: onReadData,
                          icon: const Icon(Icons.refresh)),
                    ]),
                    children: const [Text("DataList")]),
                ExpansionTile(title: const Text("CLI"), children: [
                  Row(children: <Widget>[
                    SizedBox(
                      width: 200,
                      child: TextField(
                        onSubmitted: executeCLI,
                      ),
                    ),
                  ]),
                  Row(children: <Widget>[
                    SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      padding: const EdgeInsets.all(10.0),
                      child: Text(CLIHistory),
                    ),
                  ]),
                ]),
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
    var commandnl = command + '\n';

    var uint8list = Uint8List.fromList(
        utf8.decode(commandnl.runes.toList()).runes.toList());
    int? nbwritten = mnemoPort?.write(uint8list);

    setState(() => CLIHistory +=
        (nbwritten == commandnl.length) ? commandnl : "Error $commandnl");

    switch (command) {
      case "getdata":
        waitAnswer();

        analyzeTransferBuffer();

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
        setState(() => CLIHistory +=
            (nbwritten == 5) ? "DateTime$date\n" : "Error in DateTime\n");

        break;

      case "picbootmode":

      case "picprog":

      case "help":
        break;
      case "getpicinfo":

      case "listwifinet":
      case "listcommands":

      case "getclickthreshold":

      case "getunclickdelta":

      case "getstabilizationfactor":
        waitAnswer();
        displayAnswer();

        break;
    }

    mnemoPort?.close();
  }

  void waitAnswer() {
    int counterWait = 0;
    int counterData = 0;
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
      var readBuffer = List<int>.empty(growable: true);
      if (mnemoPort != null) {
        var readBuffer8 = mnemoPort.read(mnemoPort.bytesAvailable);
        for (int i = 0; i < readBuffer8.length; i++) {
          transferBuffer.add(readBuffer8[i]);
        }
      }
    }
  }

  void analyzeTransferBuffer() {}

  void displayAnswer() {
    setState(() => CLIHistory += utf8.decode(transferBuffer));
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
