import 'package:flutter/material.dart';

/// Widget displaying software update status and controls
class SoftwareUpdateBar extends StatelessWidget {
  final bool softwareUpgradeAvailable;
  final bool updatingSoftware;
  final double downloadProgressValue;
  final String latestSoftwareVersion;
  final VoidCallback? onUpdateSoftware;

  const SoftwareUpdateBar({
    super.key,
    required this.softwareUpgradeAvailable,
    required this.updatingSoftware,
    required this.downloadProgressValue,
    required this.latestSoftwareVersion,
    this.onUpdateSoftware,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (softwareUpgradeAvailable)
          IconButton(
            color: Colors.yellowAccent,
            onPressed: !updatingSoftware ? onUpdateSoftware : null,
            icon: const Icon(Icons.update),
            tooltip: "Update Software to $latestSoftwareVersion",
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
      ],
    );
  }
}