import 'package:flutter/material.dart';

class FileIcon extends StatelessWidget {
  final String extension;
  final Color color;
  final double size;
  final String? tooltip;
  final VoidCallback? onPressed;

  const FileIcon({
    super.key,
    required this.extension,
    this.color = Colors.blue,
    this.size = 24.0,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.insert_drive_file,
              color: color,
              size: size,
            ),
            tooltip: tooltip,
            onPressed: onPressed,
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Text(
              extension.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.w800,
                color: Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
