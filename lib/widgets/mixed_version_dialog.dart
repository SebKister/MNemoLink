import 'package:flutter/material.dart';
import '../services/dmp_encoder_service.dart';

/// Dialog shown when user attempts to export mixed v5/v6 sections
class MixedVersionDialog extends StatelessWidget {
  final VersionAnalysis analysis;

  const MixedVersionDialog({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mixed DMP Versions Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your selection contains sections of different DMP versions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text('• ${analysis.v5Count} section${analysis.v5Count != 1 ? 's' : ''} in v5 format (underwater/depth data)'),
          Text('• ${analysis.v6Count} section${analysis.v6Count != 1 ? 's' : ''} in v6 format (dry cave/Lidar data)'),
          const SizedBox(height: 16),
          const Text('How would you like to export?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(MixedVersionChoice.cancel),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(MixedVersionChoice.separate),
          child: const Text('Separate Files'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(MixedVersionChoice.unifiedV6),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Export All as v6'),
        ),
      ],
    );
  }

  /// Show the dialog and return user's choice
  static Future<MixedVersionChoice> show(
    BuildContext context,
    VersionAnalysis analysis,
  ) async {
    final choice = await showDialog<MixedVersionChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MixedVersionDialog(analysis: analysis),
    );
    return choice ?? MixedVersionChoice.cancel;
  }
}

/// User's choice for handling mixed version export
enum MixedVersionChoice {
  cancel,
  separate,   // Export in separate _v5.dmp and _v6.dmp files
  unifiedV6,  // Export all as v6 format
}
