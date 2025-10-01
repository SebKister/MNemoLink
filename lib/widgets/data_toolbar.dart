import 'package:flutter/material.dart';
import 'fileicon.dart';

/// Toolbar for data operations (export, import, etc.)
class DataToolbar extends StatelessWidget {
  final bool serialBusy;
  final bool connected;
  final bool hasData;
  final bool hasSections;
  final bool hasSelectedSections;
  final bool allSectionsSelected;
  final VoidCallback? onReset;
  final VoidCallback? onReadData;
  final VoidCallback? onOpenDMP;
  final VoidCallback? onSaveDMP;
  final VoidCallback? onExportXLS;
  final VoidCallback? onExportSVX;
  final VoidCallback? onExportTH;
  final VoidCallback? onToggleSelectAll;

  const DataToolbar({
    super.key,
    required this.serialBusy,
    required this.connected,
    required this.hasData,
    required this.hasSections,
    required this.hasSelectedSections,
    required this.allSectionsSelected,
    this.onReset,
    this.onReadData,
    this.onOpenDMP,
    this.onSaveDMP,
    this.onExportXLS,
    this.onExportSVX,
    this.onExportTH,
    this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Left side - Input functions
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Select all/deselect all button
          if (hasSections)
            IconButton(
              onPressed: onToggleSelectAll,
              icon: Icon(allSectionsSelected ? Icons.deselect : Icons.select_all),
              tooltip: allSectionsSelected ? "Deselect All" : "Select All",
            ),
          
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
            tooltip: "Open DMP file(s)\nHold Ctrl/Cmd or Shift to select multiple",
            size: 24,
            color: serialBusy ? Colors.black26 : Colors.black54,
            extensionColor: serialBusy ? Colors.black26 : Colors.black87,
          ),
        ],
      ),
      leadingWidth: hasSections ? 240 : 192, // Adjust width based on whether select all button is shown
      
      // Right side - Export functions
      actions: [
        // Save DMP file button
        FileIcon(
          onPressed: (serialBusy || !hasSelectedSections) ? null : onSaveDMP,
          extension: 'DMP',
          tooltip: "Save selected surveys as DMP",
          size: 24,
          color: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black87,
        ),
        
        // Export to Excel button
        FileIcon(
          onPressed: (serialBusy || !hasSelectedSections) ? null : onExportXLS,
          extension: 'XLS',
          tooltip: "Export selected surveys as Excel",
          size: 24,
          color: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black87,
        ),
        
        // Export to Survex button
        FileIcon(
          onPressed: (serialBusy || !hasSelectedSections) ? null : onExportSVX,
          extension: 'SVX',
          tooltip: "Export selected surveys as Survex",
          size: 24,
          color: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black87,
        ),
        
        // Export to Therion button
        FileIcon(
          onPressed: (serialBusy || !hasSelectedSections) ? null : onExportTH,
          extension: 'TH',
          tooltip: "Export selected surveys as Therion",
          size: 24,
          color: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black54,
          extensionColor: (serialBusy || !hasSelectedSections) ? Colors.black26 : Colors.black87,
        ),
      ],
      backgroundColor: Colors.white30,
    );
  }

  Widget _buildInputActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSections) _buildSelectAllButton(),
        _buildClearDataButton(),
        _buildReadDataButton(),
        _buildOpenDMPButton(),
      ],
    );
  }

  Widget _buildSelectAllButton() {
    return IconButton(
      onPressed: onToggleSelectAll,
      icon: Icon(allSectionsSelected ? Icons.deselect : Icons.select_all),
      tooltip: allSectionsSelected ? "Deselect All" : "Select All",
    );
  }

  Widget _buildClearDataButton() {
    return IconButton(
      onPressed: !hasSections ? null : onReset,
      icon: const Icon(Icons.backspace_rounded),
      tooltip: "Clear local Data",
    );
  }

  Widget _buildReadDataButton() {
    return IconButton(
      onPressed: (serialBusy || !connected) ? null : onReadData,
      icon: const Icon(Icons.download_rounded),
      tooltip: "Read Data from Device",
    );
  }

  Widget _buildOpenDMPButton() {
    return FileIcon(
      onPressed: serialBusy ? null : onOpenDMP,
      icon: Icons.file_open,
      extension: 'DMP',
      tooltip: "Open DMP file",
      size: 24,
      color: serialBusy ? Colors.black26 : Colors.black54,
      extensionColor: serialBusy ? Colors.black26 : Colors.black87,
    );
  }

  List<Widget> _buildExportActions() {
    return [
      _buildSaveDMPButton(),
      _buildExportExcelButton(),
      _buildExportSurvexButton(),
      _buildExportTherionButton(),
    ];
  }

  Widget _buildSaveDMPButton() {
    return _buildExportFileIcon(
      onPressed: onSaveDMP,
      extension: 'DMP',
      tooltip: "Save selected surveys as DMP",
    );
  }

  Widget _buildExportExcelButton() {
    return _buildExportFileIcon(
      onPressed: onExportXLS,
      extension: 'XLS',
      tooltip: "Export selected surveys as Excel",
    );
  }

  Widget _buildExportSurvexButton() {
    return _buildExportFileIcon(
      onPressed: onExportSVX,
      extension: 'SVX',
      tooltip: "Export selected surveys as Survex",
    );
  }

  Widget _buildExportTherionButton() {
    return _buildExportFileIcon(
      onPressed: onExportTH,
      extension: 'TH',
      tooltip: "Export selected surveys as Therion",
    );
  }

  Widget _buildExportFileIcon({
    required VoidCallback? onPressed,
    required String extension,
    required String tooltip,
  }) {
    final isEnabled = !serialBusy && hasSelectedSections;
    return FileIcon(
      onPressed: isEnabled ? onPressed : null,
      extension: extension,
      tooltip: tooltip,
      size: 24,
      color: isEnabled ? Colors.black54 : Colors.black26,
      extensionColor: isEnabled ? Colors.black87 : Colors.black26,
    );
  }
}