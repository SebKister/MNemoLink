import 'package:flutter_test/flutter_test.dart';
import 'package:mnemolink/models/models.dart';
import 'package:mnemolink/services/dmp_encoder_service.dart';
import 'dart:io';

void main() {
  group('DMP Encoder Service Tests', () {
    late DmpEncoderService encoder;

    setUp(() {
      encoder = DmpEncoderService();
    });

    test('detectVersion should return 6 for sections with Lidar data', () {
      final shot = Shot(
        typeShot: TypeShot.std,
        length: 2.0,
        headingIn: 90.0,
        headingOut: 90.0,
        pitchIn: 0.0,
        pitchOut: 0.0,
        depthIn: 0.0,
        depthOut: 0.0,
        lidarData: const LidarData(points: [
          LidarPoint(yaw: 90.0, pitch: 0.0, distance: 2.0),
        ]),
      );

      final section = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [shot, Shot(typeShot: TypeShot.eoc)],
      );

      expect(encoder.detectVersion(section), 6);
    });

    test('detectVersion should return 6 for sections with all zero depths', () {
      final shot = Shot(
        typeShot: TypeShot.std,
        length: 2.0,
        headingIn: 90.0,
        headingOut: 90.0,
        pitchIn: 0.0,
        pitchOut: 0.0,
        depthIn: 0.0,
        depthOut: 0.0,
      );

      final section = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [shot, Shot(typeShot: TypeShot.eoc)],
      );

      expect(encoder.detectVersion(section), 6);
    });

    test('detectVersion should return 5 for sections with non-zero depths', () {
      final shot = Shot(
        typeShot: TypeShot.std,
        length: 2.0,
        headingIn: 90.0,
        headingOut: 90.0,
        pitchIn: 0.0,
        pitchOut: 0.0,
        depthIn: 1.0,
        depthOut: 2.0,
      );

      final section = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [shot, Shot(typeShot: TypeShot.eoc)],
      );

      expect(encoder.detectVersion(section), 5);
    });

    test('analyzeVersions should correctly identify all v5 sections', () {
      final section1 = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [
          Shot(typeShot: TypeShot.std, depthIn: 1.0, depthOut: 2.0),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final section2 = Section(
        name: 'AA2',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [
          Shot(typeShot: TypeShot.std, depthIn: 2.0, depthOut: 3.0),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final analysis = encoder.analyzeVersions([section1, section2]);

      expect(analysis.isAllV5, true);
      expect(analysis.isAllV6, false);
      expect(analysis.isMixed, false);
      expect(analysis.v5Count, 2);
      expect(analysis.v6Count, 0);
    });

    test('analyzeVersions should correctly identify all v6 sections', () {
      final section1 = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [
          Shot(typeShot: TypeShot.std, depthIn: 0.0, depthOut: 0.0),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final section2 = Section(
        name: 'AA2',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [
          Shot(typeShot: TypeShot.std, depthIn: 0.0, depthOut: 0.0),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final analysis = encoder.analyzeVersions([section1, section2]);

      expect(analysis.isAllV5, false);
      expect(analysis.isAllV6, true);
      expect(analysis.isMixed, false);
      expect(analysis.v5Count, 0);
      expect(analysis.v6Count, 2);
    });

    test('analyzeVersions should correctly identify mixed versions', () {
      final v5Section = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [
          Shot(typeShot: TypeShot.std, depthIn: 1.0, depthOut: 2.0),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final v6Section = Section(
        name: 'AA2',
        dateSurvey: DateTime(2025, 9, 29),
        shots: [
          Shot(typeShot: TypeShot.std, depthIn: 0.0, depthOut: 0.0),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final analysis = encoder.analyzeVersions([v5Section, v6Section]);

      expect(analysis.isAllV5, false);
      expect(analysis.isAllV6, false);
      expect(analysis.isMixed, true);
      expect(analysis.v5Count, 1);
      expect(analysis.v6Count, 1);
    });

    test('encodeSectionsToBuffer should produce valid v5 format', () {
      final section = Section(
        name: 'AA1',
        dateSurvey: DateTime(2025, 9, 29, 16, 7),
        direction: SurveyDirection.surveyIn,
        shots: [
          Shot(
            typeShot: TypeShot.std,
            length: 2.09,
            headingIn: 105.3,
            headingOut: 104.5,
            pitchIn: 4.9,
            pitchOut: 4.8,
            depthIn: 0.0,
            depthOut: 0.47,
            left: 0.49,
            right: 0.0,
            up: 0.48,
            down: 0.0,
            temperature: 16.0,
            hr: 16,
            min: 7,
            sec: 31,
            markerIndex: 0,
          ),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final buffer = encoder.encodeSectionsToBuffer([section], 5);

      expect(buffer.isNotEmpty, true);
      expect(buffer[0], 5); // Version
      expect(buffer[1], 68); // Magic byte A
      expect(buffer[2], 89); // Magic byte B
      expect(buffer[3], 101); // Magic byte C
      expect(buffer[4], 25); // Year (2025)
      expect(buffer[5], 9); // Month
      expect(buffer[6], 29); // Day
      expect(buffer[7], 16); // Hour
      expect(buffer[8], 7); // Minute
      expect(buffer[9], 65); // 'A'
      expect(buffer[10], 65); // 'A'
      expect(buffer[11], 49); // '1'
      expect(buffer[12], 0); // Direction IN
    });

    test('encodeSectionsToBuffer should include correct magic bytes for shots', () {
      final section = Section(
        name: 'TST',
        dateSurvey: DateTime(2025, 1, 1),
        shots: [
          Shot(typeShot: TypeShot.std),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final buffer = encoder.encodeSectionsToBuffer([section], 5);

      // Find shot start (after section header of 13 bytes)
      expect(buffer[13], 57); // Shot start magic A
      expect(buffer[14], 67); // Shot start magic B
      expect(buffer[15], 77); // Shot start magic C
      expect(buffer[16], 2); // TypeShot.std
    });

    test('writeBufferToFile should create valid CSV format', () async {
      final buffer = [6, 68, 89, 101, 25, 9, 29];
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/test.dmp');

      await encoder.writeBufferToFile(buffer, testFile);

      final contents = await testFile.readAsString();
      expect(contents, '6;68;89;101;25;9;29;');

      // Clean up
      await testFile.delete();
      await tempDir.delete();
    });

    test('broken shots should be included in export with correct format', () {
      final section = Section(
        name: 'BRK',
        dateSurvey: DateTime(2025, 1, 1),
        brokenFlag: true, // Section marked as broken
        shots: [
          Shot(typeShot: TypeShot.std),
          Shot(typeShot: TypeShot.eoc),
        ],
      );

      final buffer = encoder.encodeSectionsToBuffer([section], 5);

      // Should still encode the section with proper magic bytes
      expect(buffer.isNotEmpty, true);
      expect(buffer[0], 5); // Version
      expect(buffer[13], 57); // Shot start magic (correct format)
    });
  });
}
