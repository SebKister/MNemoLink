import 'package:flutter/material.dart';

/// Widget for network connection and scanning functionality
class NetworkConnectionPanel extends StatelessWidget {
  final bool scanningNetwork;
  final bool networkDeviceFound;
  final String networkScanProgress;
  final TextEditingController ipController;
  final String ipMNemo;
  final VoidCallback onNetworkScan;
  final VoidCallback onNetworkScanStop;
  final VoidCallback? onNetworkDMP;
  final Function(String) onIPChanged;

  const NetworkConnectionPanel({
    super.key,
    required this.scanningNetwork,
    required this.networkDeviceFound,
    required this.networkScanProgress,
    required this.ipController,
    required this.ipMNemo,
    required this.onNetworkScan,
    required this.onNetworkScanStop,
    this.onNetworkDMP,
    required this.onIPChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Download from the network"),
        
        IconButton(
          onPressed: scanningNetwork ? onNetworkScanStop : onNetworkScan,
          icon: !scanningNetwork 
              ? const Icon(Icons.search)
              : const Icon(Icons.search_off),
          tooltip: "Scan local network for wifi connected devices",
        ),
        
        TextField(
          textAlign: TextAlign.center,
          controller: ipController,
          showCursor: true,
          onChanged: onIPChanged,
          autofocus: true,
          decoration: InputDecoration(
            floatingLabelAlignment: FloatingLabelAlignment.center,
            labelText: scanningNetwork ? networkScanProgress : "IP",
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
          onPressed: !networkDeviceFound ? null : onNetworkDMP,
          icon: const Icon(Icons.wifi),
          tooltip: "Download from wifi connected device",
        ),
      ],
    );
  }
}