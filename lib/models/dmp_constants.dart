/// DMP (Data Memory Package) file format constants
///
/// These constants define the binary structure of MNemo v2 DMP files.
/// See: doc/MNemo DMP File Format - Complete Documentation.md
class DmpConstants {
  // Private constructor to prevent instantiation
  DmpConstants._();

  // ============================================================================
  // FILE VERSION MAGIC BYTES (Version 5+)
  // ============================================================================

  /// Magic byte A for file version header (version 5+)
  static const int fileVersionMagicA = 68; // 0x44

  /// Magic byte B for file version header (version 5+)
  static const int fileVersionMagicB = 89; // 0x59

  /// Magic byte C for file version header (version 5+)
  static const int fileVersionMagicC = 101; // 0x65

  // ============================================================================
  // SHOT RECORD MAGIC BYTES (Version 5+)
  // ============================================================================

  /// Magic byte A for shot record start (version 5+)
  static const int shotStartMagicA = 57; // 0x39

  /// Magic byte B for shot record start (version 5+)
  static const int shotStartMagicB = 67; // 0x43

  /// Magic byte C for shot record start (version 5+)
  static const int shotStartMagicC = 77; // 0x4D

  /// Magic byte A for shot record end (version 5+)
  static const int shotEndMagicA = 95; // 0x5F

  /// Magic byte B for shot record end (version 5+)
  static const int shotEndMagicB = 25; // 0x19

  /// Magic byte C for shot record end (version 5+)
  static const int shotEndMagicC = 35; // 0x23

  // ============================================================================
  // LIDAR DATA MAGIC BYTES (Version 6)
  // ============================================================================

  /// Magic byte A for Lidar data block start (version 6)
  static const int lidarStartMagicA = 32; // 0x20 - VOLSTART_VALA

  /// Magic byte B for Lidar data block start (version 6)
  static const int lidarStartMagicB = 33; // 0x21 - VOLSTART_VALB

  /// Magic byte C for Lidar data block start (version 6)
  static const int lidarStartMagicC = 34; // 0x22 - VOLSTART_VALC

  // ============================================================================
  // FORMAT VERSION LIMITS
  // ============================================================================

  /// Minimum supported DMP file version
  static const int minSupportedVersion = 2;

  /// Maximum supported DMP file version
  static const int maxSupportedVersion = 6;

  /// First version with magic byte validation
  static const int firstVersionWithMagicBytes = 5;

  /// First version with temperature and time data
  static const int firstVersionWithTemperature = 3;

  /// First version with LRUD passage measurements
  static const int firstVersionWithLRUD = 4;

  /// First version with optional Lidar data
  static const int firstVersionWithLidar = 6;

  // ============================================================================
  // RECORD SIZES
  // ============================================================================

  /// Size of section header in bytes
  static const int sectionHeaderSize = 13;

  /// Size of shot record in bytes (v5+, excluding optional Lidar data)
  static const int shotRecordSize = 35;

  /// Size of each Lidar point in bytes
  static const int lidarPointSize = 6;

  // ============================================================================
  // VALIDATION HELPERS
  // ============================================================================

  /// Check if a version number is valid
  static bool isValidVersion(int version) {
    return version >= minSupportedVersion && version <= maxSupportedVersion;
  }

  /// Check if a version uses magic bytes
  static bool usesMagicBytes(int version) {
    return version >= firstVersionWithMagicBytes;
  }

  /// Check if a version supports temperature data
  static bool hasTemperature(int version) {
    return version >= firstVersionWithTemperature;
  }

  /// Check if a version supports LRUD data
  static bool hasLRUD(int version) {
    return version >= firstVersionWithLRUD;
  }

  /// Check if a version supports Lidar data
  static bool hasLidar(int version) {
    return version >= firstVersionWithLidar;
  }
}
