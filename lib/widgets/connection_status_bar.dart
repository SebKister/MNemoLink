import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Widget displaying device connection status in the app bar
class ConnectionStatusBar extends StatelessWidget {
  final bool connected;
  final bool detected;
  final bool detectedOnly;
  final bool serialBusy;
  final bool firmwareUpgradeAvailable;
  final bool updatingFirmware;
  final String nameDevice;
  final String mnemoPortAddress;
  final String? serialNumber;
  final String firmwareVersion;
  final int timeON;
  final int timeSurvey;
  final VoidCallback onRefreshMnemo;
  final VoidCallback? onUpdateFirmware;

  const ConnectionStatusBar({
    super.key,
    required this.connected,
    required this.detected,
    required this.detectedOnly,
    required this.serialBusy,
    required this.firmwareUpgradeAvailable,
    required this.updatingFirmware,
    required this.nameDevice,
    required this.mnemoPortAddress,
    this.serialNumber,
    required this.firmwareVersion,
    required this.timeON,
    required this.timeSurvey,
    required this.onRefreshMnemo,
    this.onUpdateFirmware,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: connected || detected
            ? _buildConnectedStatus()
            : _buildDisconnectedStatus(),
      ),
    );
  }

  List<Widget> _buildConnectedStatus() {
    return [
      if (serialBusy)
        Container(
          padding: const EdgeInsets.only(right: 30),
          child: LoadingAnimationWidget.inkDrop(
            color: Colors.white60,
            size: 20,
          ),
        ),
      
      if (connected && firmwareUpgradeAvailable)
        IconButton(
          color: Colors.yellowAccent,
          onPressed: !updatingFirmware ? onUpdateFirmware : null,
          icon: const Icon(Icons.update),
          tooltip: "Update Firmware to $firmwareVersion",
        ),
      
      if (connected)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("[$nameDevice] Connected on $mnemoPortAddress"),
            Text(
              style: const TextStyle(fontSize: 10),
              'SN ${serialNumber ?? "Unknown"} FW $firmwareVersion',
            ),
            Text(
              style: const TextStyle(fontSize: 9),
              'ON: $timeON min - Survey: $timeSurvey min',
            ),
          ],
        ),
      
      IconButton(
        onPressed: onRefreshMnemo,
        icon: const Icon(Icons.refresh),
        tooltip: "Search for Device",
      ),
    ];
  }

  List<Widget> _buildDisconnectedStatus() {
    return [
      Text(
        detectedOnly 
            ? "Mnemo detected - Connection failed -"
            : "Mnemo Not detected"
      ),
      IconButton(
        onPressed: onRefreshMnemo,
        icon: const Icon(Icons.refresh),
        tooltip: "Search for Device",
      ),
    ];
  }
}