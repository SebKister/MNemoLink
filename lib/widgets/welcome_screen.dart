import 'dart:io';
import 'package:flutter/material.dart';
import 'fileicon.dart';
import 'network_connection_panel.dart';

/// Welcome screen shown when no device is connected and no data is loaded
class WelcomeScreen extends StatelessWidget {
  final bool scanningNetwork;
  final bool networkDeviceFound;
  final String networkScanProgress;
  final TextEditingController ipController;
  final String ipMNemo;
  final VoidCallback onRefreshMnemo;
  final VoidCallback onOpenDMP;
  final VoidCallback onNetworkScan;
  final VoidCallback onNetworkScanStop;
  final VoidCallback? onNetworkDMP;
  final Function(String) onIPChanged;

  const WelcomeScreen({
    super.key,
    required this.scanningNetwork,
    required this.networkDeviceFound,
    required this.networkScanProgress,
    required this.ipController,
    required this.ipMNemo,
    required this.onRefreshMnemo,
    required this.onOpenDMP,
    required this.onNetworkScan,
    required this.onNetworkScanStop,
    this.onNetworkDMP,
    required this.onIPChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Device connection section (desktop only)
          if (!Platform.isAndroid && !Platform.isIOS) ...[
            const Text("Connect the Mnemo to your computer and press the refresh button"),
            IconButton(
              onPressed: onRefreshMnemo,
              icon: const Icon(Icons.refresh),
              tooltip: "Search for Device",
            ),
            const SizedBox(width: 10, height: 60),
          ],
          
          // File operations section
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
          const SizedBox(width: 10, height: 60),
          
          // Network connection section
          NetworkConnectionPanel(
            scanningNetwork: scanningNetwork,
            networkDeviceFound: networkDeviceFound,
            networkScanProgress: networkScanProgress,
            ipController: ipController,
            ipMNemo: ipMNemo,
            onNetworkScan: onNetworkScan,
            onNetworkScanStop: onNetworkScanStop,
            onNetworkDMP: onNetworkDMP,
            onIPChanged: onIPChanged,
          ),
        ],
      ),
    );
  }
}