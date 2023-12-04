import 'package:flutter/material.dart';

class FileIcon extends StatelessWidget {
  final String extension;
  final Color color;
  final Color extensionColor;
  final double size;
  final String? tooltip;
  final VoidCallback? onPressed;

  const FileIcon({
    super.key,
    required this.extension,
    this.color = Colors.blue,
    this.extensionColor = Colors.blue,
    this.size = 24.0,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size),
          child: ClipOval(
            child: SizedBox(
              width: size * 1.6,
              height: size * 1.6,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(
                    Icons.insert_drive_file,
                    color: color,
                    size: size,
                  ),
                  Positioned(
                    bottom: 4,
                    child: Text(
                      extension.toUpperCase(),
                      style: TextStyle(
                        fontSize: size * 0.5,
                        fontWeight: FontWeight.w800,
                        color: extensionColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
