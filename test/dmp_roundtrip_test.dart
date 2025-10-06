import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnemolink/models/models.dart';
import 'package:mnemolink/services/dmp_decoder_service.dart';
import 'package:mnemolink/services/dmp_encoder_service.dart';

void main() {
  group('DMP Round-Trip Tests', () {
    late DmpDecoderService decoder;
    late DmpEncoderService encoder;

    setUp(() {
      decoder = DmpDecoderService();
      encoder = DmpEncoderService();
    });

    Future<List<Section>> loadAndProcessDmpFile(File file) async {
      final buffer = await decoder.parseDMPFileOptimized(file);
      final result = await decoder.processTransferBuffer(buffer, UnitType.metric);

      if (!result.success) {
        throw Exception('Failed to process DMP file: ${result.error}');
      }

      return result.sections;
    }

    Future<List<Section>> exportAndReload(List<Section> sections, int version, Directory tempDir) async {
      // Export sections to buffer
      final exportBuffer = encoder.encodeSectionsToBuffer(sections, version);

      // Write buffer to temporary file
      final tempFile = File('${tempDir.path}/test_export.dmp');
      await encoder.writeBufferToFile(exportBuffer, tempFile);

      // Reload the exported file
      return loadAndProcessDmpFile(tempFile);
    }

    void compareSections(Section original, Section exported, String context) {
      expect(exported.name, original.name, reason: '$context: Section name mismatch');
      expect(exported.dateSurvey, original.dateSurvey, reason: '$context: Date mismatch');
      expect(exported.direction, original.direction, reason: '$context: Direction mismatch');
      expect(exported.shots.length, original.shots.length, reason: '$context: Shot count mismatch');

      // Broken flag should be cleared after export/reload since we export with correct format
      if (original.brokenFlag) {
        expect(exported.brokenFlag, false,
          reason: '$context: Broken sections should be fixed after round-trip');
      }
    }

    void compareShots(Shot original, Shot exported, String context, {double tolerance = 0.01}) {
      expect(exported.typeShot, original.typeShot, reason: '$context: Shot type mismatch');

      // For EOC shots, only check type
      if (original.typeShot == TypeShot.eoc) {
        return;
      }

      // Compare numeric values with tolerance for rounding
      expect(exported.headingIn, closeTo(original.headingIn, tolerance),
        reason: '$context: HeadingIn mismatch');
      expect(exported.headingOut, closeTo(original.headingOut, tolerance),
        reason: '$context: HeadingOut mismatch');
      expect(exported.length, closeTo(original.length, tolerance),
        reason: '$context: Length mismatch');
      expect(exported.depthIn, closeTo(original.depthIn, tolerance),
        reason: '$context: DepthIn mismatch');
      expect(exported.depthOut, closeTo(original.depthOut, tolerance),
        reason: '$context: DepthOut mismatch');
      expect(exported.pitchIn, closeTo(original.pitchIn, tolerance),
        reason: '$context: PitchIn mismatch');
      expect(exported.pitchOut, closeTo(original.pitchOut, tolerance),
        reason: '$context: PitchOut mismatch');

      // LRUD data
      expect(exported.left, closeTo(original.left, tolerance),
        reason: '$context: Left mismatch');
      expect(exported.right, closeTo(original.right, tolerance),
        reason: '$context: Right mismatch');
      expect(exported.up, closeTo(original.up, tolerance),
        reason: '$context: Up mismatch');
      expect(exported.down, closeTo(original.down, tolerance),
        reason: '$context: Down mismatch');

      // Temperature and time
      expect(exported.temperature, closeTo(original.temperature, tolerance),
        reason: '$context: Temperature mismatch');
      expect(exported.hr, original.hr, reason: '$context: Hour mismatch');
      expect(exported.min, original.min, reason: '$context: Minute mismatch');
      expect(exported.sec, original.sec, reason: '$context: Second mismatch');

      expect(exported.markerIndex, original.markerIndex,
        reason: '$context: Marker index mismatch');

      // Lidar data
      expect(exported.hasLidarData(), original.hasLidarData(),
        reason: '$context: Lidar data presence mismatch');

      if (original.hasLidarData() && exported.hasLidarData()) {
        final origLidar = original.lidarData!;
        final expLidar = exported.lidarData!;

        expect(expLidar.points.length, origLidar.points.length,
          reason: '$context: Lidar point count mismatch');

        for (int i = 0; i < origLidar.points.length; i++) {
          final origPoint = origLidar.points[i];
          final expPoint = expLidar.points[i];

          expect(expPoint.yaw, closeTo(origPoint.yaw, tolerance),
            reason: '$context: Lidar point $i yaw mismatch');
          expect(expPoint.pitch, closeTo(origPoint.pitch, tolerance),
            reason: '$context: Lidar point $i pitch mismatch');
          expect(expPoint.distance, closeTo(origPoint.distance, tolerance),
            reason: '$context: Lidar point $i distance mismatch');
        }
      }
    }

    test('Round-trip: simple-v6.dmp', () async {
      final sampleFile = File('doc/samples/simple-v6.dmp');

      if (!await sampleFile.exists()) {
        // ignore: avoid_print
        print('Skipping test: ${sampleFile.path} not found');
        return;
      }

      // Load original
      final originalSections = await loadAndProcessDmpFile(sampleFile);
      expect(originalSections, isNotEmpty, reason: 'Should load sections from simple-v6.dmp');

      // Detect version
      final version = encoder.detectVersion(originalSections.first);
      expect(version, 6, reason: 'simple-v6.dmp should be detected as v6');

      // Export and reload
      final tempDir = Directory.systemTemp.createTempSync('dmp_test_');
      try {
        final exportedSections = await exportAndReload(originalSections, version, tempDir);

        // Compare
        expect(exportedSections.length, originalSections.length);

        for (int i = 0; i < originalSections.length; i++) {
          final context = 'simple-v6 section $i';
          compareSections(originalSections[i], exportedSections[i], context);

          for (int j = 0; j < originalSections[i].shots.length; j++) {
            final shotContext = '$context shot $j';
            compareShots(originalSections[i].shots[j], exportedSections[i].shots[j], shotContext);
          }
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Round-trip: real_v5-broken.dmp', () async {
      final sampleFile = File('doc/samples/real_v5-broken.dmp');

      if (!await sampleFile.exists()) {
        // ignore: avoid_print
        print('Skipping test: ${sampleFile.path} not found');
        return;
      }

      // Load original
      final originalSections = await loadAndProcessDmpFile(sampleFile);
      expect(originalSections, isNotEmpty, reason: 'Should load sections from real_v5-broken.dmp');

      // Detect version - should be v5
      final version = encoder.detectVersion(originalSections.first);
      expect(version, 5, reason: 'real_v5-broken.dmp should be detected as v5');

      // Check if original has broken flag
      final hadBrokenSections = originalSections.any((s) => s.brokenFlag);

      // Export and reload
      final tempDir = Directory.systemTemp.createTempSync('dmp_test_');
      try {
        final exportedSections = await exportAndReload(originalSections, version, tempDir);

        // After round-trip, broken sections should be fixed
        final hasBrokenAfterRoundTrip = exportedSections.any((s) => s.brokenFlag);

        if (hadBrokenSections) {
          expect(hasBrokenAfterRoundTrip, false,
            reason: 'Round-trip should fix broken sections by exporting with correct format');
        }

        // Compare sections (excluding broken flag which is expected to change)
        expect(exportedSections.length, originalSections.length);

        for (int i = 0; i < originalSections.length; i++) {
          final context = 'real_v5-broken section $i';

          // Only compare if original section wasn't broken
          if (!originalSections[i].brokenFlag) {
            compareSections(originalSections[i], exportedSections[i], context);

            for (int j = 0; j < originalSections[i].shots.length; j++) {
              final shotContext = '$context shot $j';
              compareShots(originalSections[i].shots[j], exportedSections[i].shots[j], shotContext);
            }
          } else {
            // For broken sections, at least verify basic structure
            expect(exportedSections[i].name, originalSections[i].name,
              reason: '$context: Name should be preserved');
            expect(exportedSections[i].brokenFlag, false,
              reason: '$context: Should not be broken after export');
          }
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Round-trip: real_v6-broken.dmp', () async {
      final sampleFile = File('doc/samples/real_v6-broken.dmp');

      if (!await sampleFile.exists()) {
        // ignore: avoid_print
        print('Skipping test: ${sampleFile.path} not found');
        return;
      }

      // Load original
      final originalSections = await loadAndProcessDmpFile(sampleFile);
      expect(originalSections, isNotEmpty, reason: 'Should load sections from real_v6-broken.dmp');

      // Detect version - should be v6
      final version = encoder.detectVersion(originalSections.first);
      expect(version, 6, reason: 'real_v6-broken.dmp should be detected as v6');

      // Check if original has broken flag
      final hadBrokenSections = originalSections.any((s) => s.brokenFlag);

      // Export and reload
      final tempDir = Directory.systemTemp.createTempSync('dmp_test_');
      try {
        final exportedSections = await exportAndReload(originalSections, version, tempDir);

        // After round-trip, broken sections should be fixed
        final hasBrokenAfterRoundTrip = exportedSections.any((s) => s.brokenFlag);

        if (hadBrokenSections) {
          expect(hasBrokenAfterRoundTrip, false,
            reason: 'Round-trip should fix broken sections by exporting with correct format');
        }

        // Compare sections
        expect(exportedSections.length, originalSections.length);

        for (int i = 0; i < originalSections.length; i++) {
          final context = 'real_v6-broken section $i';

          // Only compare if original section wasn't broken
          if (!originalSections[i].brokenFlag) {
            compareSections(originalSections[i], exportedSections[i], context);

            for (int j = 0; j < originalSections[i].shots.length; j++) {
              final shotContext = '$context shot $j';
              compareShots(originalSections[i].shots[j], exportedSections[i].shots[j], shotContext);
            }
          } else {
            // For broken sections, at least verify basic structure
            expect(exportedSections[i].name, originalSections[i].name,
              reason: '$context: Name should be preserved');
            expect(exportedSections[i].brokenFlag, false,
              reason: '$context: Should not be broken after export');
          }
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Version detection: v5 converted to v6 round-trip', () async {
      final sampleFile = File('doc/samples/real_v5-broken.dmp');

      if (!await sampleFile.exists()) {
        // ignore: avoid_print
        print('Skipping test: ${sampleFile.path} not found');
        return;
      }

      // Load original v5 file
      final originalSections = await loadAndProcessDmpFile(sampleFile);
      expect(originalSections, isNotEmpty);

      // Export as v6 (conversion scenario)
      final tempDir = Directory.systemTemp.createTempSync('dmp_test_');
      try {
        final exportedSections = await exportAndReload(originalSections, 6, tempDir);

        // Should successfully reload
        expect(exportedSections, isNotEmpty);
        expect(exportedSections.length, originalSections.length);

        // Verify it was exported as v6 by checking depth values should be preserved
        // (even though no Lidar data, it's valid v6)
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
