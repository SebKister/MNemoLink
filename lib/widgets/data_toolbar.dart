import 'package:flutter/material.dart';
import 'fileicon.dart';

/// Toolbar for data operations (export, import, etc.)
class DataToolbar extends StatelessWidget {
  final bool serialBusy;
  final bool connected;
  final bool hasData;
  final bool hasSections;
  final VoidCallback? onReset;
  final VoidCallback? onReadData;
  final VoidCallback? onOpenDMP;
  final VoidCallback? onSaveDMP;
  final VoidCallback? onExportXLS;
  final VoidCallback? onExportSVX;
  final VoidCallback? onExportTH;

  const DataToolbar({
    super.key,
    required this.serialBusy,
    required this.connected,
    required this.hasData,
    required this.hasSections,
    this.onReset,
    this.onReadData,
    this.onOpenDMP,
    this.onSaveDMP,
    this.onExportXLS,
    this.onExportSVX,
    this.onExportTH,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: [
        // Clear data button
        IconButton(
          onPressed: !hasSections ? null : onReset,
          icon: const Icon(Icons.backspace_rounded),
          tooltip: "Clear local Data",
        ),
        
        // Read data from device button
        IconButton(
          onPressed: (serialBusy || !connected) ? null : onReadData,
          icon: const Icon(Icons.download_rounded),
          tooltip: "Read Data from Device",
        ),
        
        // Open DMP file button
        FileIcon(
          onPressed: serialBusy ? null : onOpenDMP,
          icon: Icons.file_open,
          extension: 'DMP',
          tooltip: "Open DMP file",
          size: 24,
          color: serialBusy ? Colors.black26 : Colors.black54,
          extensionColor: serialBusy ? Colors.black26 : Colors.black87,
        ),
        
        // Save DMP file button
        FileIcon(
          onPressed: (serialBusy || !hasData) ? null : onSaveDMP,
          extension: 'DMP',
          tooltip: "Save as DMP",
          size: 24,
          color: (serialBusy || !hasData) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasData) ? Colors.black26 : Colors.black87,
        ),
        
        // Export to Excel button
        FileIcon(
          onPressed: (serialBusy || !hasSections) ? null : onExportXLS,
          extension: 'XLS',
          tooltip: "Export as Excel",
          size: 24,
          color: (serialBusy || !hasSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSections) ? Colors.black26 : Colors.black87,
        ),
        
        // Export to Survex button
        FileIcon(
          onPressed: (serialBusy || !hasSections) ? null : onExportSVX,
          extension: 'SVX',
          tooltip: "Export as Survex",
          size: 24,
          color: (serialBusy || !hasSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSections) ? Colors.black26 : Colors.black87,
        ),
        
        // Export to Therion button
        FileIcon(
          onPressed: (serialBusy || !hasSections) ? null : onExportTH,
          extension: 'TH',
          tooltip: "Export as Therion",
          size: 24,
          color: (serialBusy || !hasSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSections) ? Colors.black26 : Colors.black87,
        ),
      ],
      backgroundColor: Colors.white30,
    );
  }
}