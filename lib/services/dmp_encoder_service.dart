import 'dart:io';
import 'dart:typed_data';
import '../models/models.dart';

/// Service for encoding sections to DMP format
class DmpEncoderService {

  /// Detect the appropriate DMP version for a section
  /// Returns 6 if section has Lidar data OR all shots have depth == 0.0
  /// Returns 5 otherwise
  int detectVersion(Section section) {
    final shots = section.shots;
    if (shots.isEmpty) return 5;

    // Check if any shot has Lidar data
    for (final shot in shots) {
      if (shot.hasLidarData()) {
        return 6;
      }
    }

    // Check if all shots (excluding EOC) have depth == 0.0
    bool allDepthsZero = true;
    for (int i = 0; i < shots.length - 1; i++) {  // Exclude last shot (EOC)
      final shot = shots[i];
      if (shot.depthIn != 0.0 || shot.depthOut != 0.0) {
        allDepthsZero = false;
        break;
      }
    }

    return allDepthsZero ? 6 : 5;
  }

  /// Analyze selected sections to determine version distribution
  VersionAnalysis analyzeVersions(List<Section> sections) {
    final v5Sections = <Section>[];
    final v6Sections = <Section>[];

    for (final section in sections) {
      final version = detectVersion(section);
      if (version == 6) {
        v6Sections.add(section);
      } else {
        v5Sections.add(section);
      }
    }

    return VersionAnalysis(
      v5Sections: v5Sections,
      v6Sections: v6Sections,
    );
  }

  /// Encode multiple sections to a DMP buffer
  List<int> encodeSectionsToBuffer(List<Section> sections, int version) {
    final buffer = <int>[];

    for (final section in sections) {
      _encodeSectionToBuffer(section, version, buffer);
    }

    return buffer;
  }

  /// Encode a single section to the buffer
  void _encodeSectionToBuffer(Section section, int version, List<int> buffer) {
    // Section header (13 bytes)
    buffer.add(version);

    // Magic bytes for version 5+
    if (DmpConstants.usesMagicBytes(version)) {
      buffer.add(DmpConstants.fileVersionMagicA);
      buffer.add(DmpConstants.fileVersionMagicB);
      buffer.add(DmpConstants.fileVersionMagicC);
    }

    // Date/time
    buffer.add(section.dateSurvey.year - 2000);
    buffer.add(section.dateSurvey.month);
    buffer.add(section.dateSurvey.day);
    buffer.add(section.dateSurvey.hour);
    buffer.add(section.dateSurvey.minute);

    // Section name (3 characters)
    final nameBytes = section.name.padRight(3, ' ').substring(0, 3).codeUnits;
    buffer.add(nameBytes[0]);
    buffer.add(nameBytes[1]);
    buffer.add(nameBytes[2]);

    // Direction
    buffer.add(section.direction.index);

    // Encode all shots (including broken ones, but with correct magic bytes)
    for (final shot in section.shots) {
      _encodeShotToBuffer(shot, version, buffer);
    }
  }

  /// Encode a single shot to the buffer
  void _encodeShotToBuffer(Shot shot, int version, List<int> buffer) {
    // Shot start magic bytes for version 5+
    if (DmpConstants.usesMagicBytes(version)) {
      buffer.add(DmpConstants.shotStartMagicA);
      buffer.add(DmpConstants.shotStartMagicB);
      buffer.add(DmpConstants.shotStartMagicC);
    }

    // Shot type
    buffer.add(shot.typeShot.index);

    // For EOC shots, write minimal data
    if (shot.typeShot == TypeShot.eoc) {
      // 9 zero bytes for measurements (heading, length, depth, pitch)
      for (int i = 0; i < 9; i++) {
        buffer.add(0);
      }
      return;
    }

    // Core measurements (14 bytes)
    _writeInt16(buffer, (shot.headingIn * 10).round());
    _writeInt16(buffer, (shot.headingOut * 10).round());
    _writeInt16(buffer, (shot.length * 100).round());
    _writeInt16(buffer, (shot.depthIn * 100).round());
    _writeInt16(buffer, (shot.depthOut * 100).round());
    _writeInt16(buffer, (shot.pitchIn * 10).round());
    _writeInt16(buffer, (shot.pitchOut * 10).round());

    // LRUD data (8 bytes) - version 4+
    if (DmpConstants.hasLRUD(version)) {
      _writeInt16(buffer, (shot.left * 100).round());
      _writeInt16(buffer, (shot.right * 100).round());
      _writeInt16(buffer, (shot.up * 100).round());
      _writeInt16(buffer, (shot.down * 100).round());
    }

    // Temperature and time (5 bytes) - version 3+
    if (DmpConstants.hasTemperature(version)) {
      _writeInt16(buffer, (shot.temperature * 10).round());
      buffer.add(shot.hr);
      buffer.add(shot.min);
      buffer.add(shot.sec);
    }

    // Marker index (1 byte)
    buffer.add(shot.markerIndex);

    // Shot end magic bytes for version 5+
    if (DmpConstants.usesMagicBytes(version)) {
      buffer.add(DmpConstants.shotEndMagicA);
      buffer.add(DmpConstants.shotEndMagicB);
      buffer.add(DmpConstants.shotEndMagicC);
    }

    // Lidar data for version 6
    if (DmpConstants.hasLidar(version) && shot.hasLidarData()) {
      _encodeLidarData(shot.lidarData!, buffer);
    }
  }

  /// Encode Lidar data to buffer (V6 only)
  void _encodeLidarData(LidarData lidarData, List<int> buffer) {
    // Lidar magic bytes
    buffer.add(DmpConstants.lidarStartMagicA);
    buffer.add(DmpConstants.lidarStartMagicB);
    buffer.add(DmpConstants.lidarStartMagicC);

    // Data length (little-endian)
    final dataLength = lidarData.points.length * 6;
    _writeInt16(buffer, dataLength);

    // Lidar points (big-endian for yaw/pitch/distance)
    for (final point in lidarData.points) {
      _writeUInt16BigEndian(buffer, (point.yaw * 100).round());
      _writeInt16BigEndian(buffer, (point.pitch * 100).round());
      _writeUInt16BigEndian(buffer, (point.distance * 100).round());
    }
  }

  /// Write a 16-bit signed integer to buffer (little-endian)
  void _writeInt16(List<int> buffer, int value) {
    final bytes = Uint8List(2);
    final byteData = ByteData.sublistView(bytes);
    byteData.setInt16(0, value, Endian.little);
    buffer.add(bytes[1]);
    buffer.add(bytes[0]);
  }

  /// Write a 16-bit unsigned integer to buffer (big-endian) for Lidar data
  void _writeUInt16BigEndian(List<int> buffer, int value) {
    final bytes = Uint8List(2);
    final byteData = ByteData.sublistView(bytes);
    byteData.setUint16(0, value, Endian.big);
    buffer.add(bytes[1]);
    buffer.add(bytes[0]);
  }

  /// Write a 16-bit signed integer to buffer (big-endian) for Lidar data
  void _writeInt16BigEndian(List<int> buffer, int value) {
    final bytes = Uint8List(2);
    final byteData = ByteData.sublistView(bytes);
    byteData.setInt16(0, value, Endian.big);
    buffer.add(bytes[1]);
    buffer.add(bytes[0]);
  }

  /// Write buffer to file in CSV format
  Future<void> writeBufferToFile(List<int> buffer, File file) async {
    final sink = file.openWrite();

    for (int i = 0; i < buffer.length; i++) {
      final value = (buffer[i] >= -128 && buffer[i] <= 127)
          ? buffer[i]
          : -(256 - buffer[i]);
      sink.write("$value;");
    }

    await sink.flush();
    await sink.close();
  }
}

/// Analysis result of version distribution in sections
class VersionAnalysis {
  final List<Section> v5Sections;
  final List<Section> v6Sections;

  VersionAnalysis({
    required this.v5Sections,
    required this.v6Sections,
  });

  bool get hasV5 => v5Sections.isNotEmpty;
  bool get hasV6 => v6Sections.isNotEmpty;
  bool get isMixed => hasV5 && hasV6;
  bool get isAllV5 => hasV5 && !hasV6;
  bool get isAllV6 => hasV6 && !hasV5;

  int get v5Count => v5Sections.length;
  int get v6Count => v6Sections.length;
  int get totalCount => v5Count + v6Count;
}
