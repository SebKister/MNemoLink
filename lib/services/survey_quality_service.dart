import 'dart:math';
import '../models/models.dart';

/// Service for scoring survey quality based on various metrics
class SurveyQualityService {
  // Scoring weights for different metrics (should sum to 1.0)
  static const double _measurementConsistencyWeight = 0.50;
  static const double _lengthValidationWeight = 0.35;
  static const double _dataCompletenessWeight = 0.15;

  /// Score a single survey section
  SurveyQuality scoreSurveySection(Section section) {
    final subscores = <String, double>{};
    final issues = <QualityIssue>[];

    // Calculate individual metric scores
    final measurementScore = _scoreMeasurementConsistency(section, issues);
    subscores['measurement_consistency'] = measurementScore;

    final lengthScore = _scoreLengthValidation(section, issues);
    subscores['length_validation'] = lengthScore;

    final completenessScore = _scoreDataCompleteness(section, issues);
    subscores['data_completeness'] = completenessScore;

    // Calculate weighted total score
    final totalScore = (measurementScore * _measurementConsistencyWeight) +
                      (lengthScore * _lengthValidationWeight) +
                      (completenessScore * _dataCompletenessWeight);

    // Convert to star rating (1-5 stars)
    final stars = _scoreToStars(totalScore);

    return SurveyQuality(
      stars: stars,
      score: totalScore,
      issues: issues,
      subscores: subscores,
    );
  }

  /// Score measurement consistency (heading and pitch in/out agreement)
  double _scoreMeasurementConsistency(Section section, List<QualityIssue> issues) {
    if (section.shots.isEmpty) return 0.0;

    double totalPenalty = 0.0;
    int validShots = 0;
    double maxHeadingDiff = 0.0;
    double maxPitchDiff = 0.0;

    for (int i = 0; i < section.shots.length - 1; i++) { // Exclude EOC shot
      final shot = section.shots[i];
      
      // Check heading consistency (angles are in degrees * 10)
      final headingDiff = ((shot.headingOut - shot.headingIn).abs() / 10.0) % 360;
      final normalizedHeadingDiff = headingDiff > 180 ? 360 - headingDiff : headingDiff;
      
      // Check pitch consistency
      final pitchDiff = (shot.pitchOut - shot.pitchIn).abs() / 10.0;

      // Track maximum discrepancies
      maxHeadingDiff = max(maxHeadingDiff, normalizedHeadingDiff);
      maxPitchDiff = max(maxPitchDiff, pitchDiff);

      if (normalizedHeadingDiff > 20) {
        totalPenalty += 30.0;
        issues.add(QualityIssue(
          category: 'Measurement Consistency',
          description: 'Shot ${i + 1}: Large heading difference (${normalizedHeadingDiff.toStringAsFixed(1)}°)',
          severity: 'high',
          shotIndex: i,
        ));
      } else if (normalizedHeadingDiff > 10) {
        totalPenalty += 15.0;
        issues.add(QualityIssue(
          category: 'Measurement Consistency',
          description: 'Shot ${i + 1}: Moderate heading difference (${normalizedHeadingDiff.toStringAsFixed(1)}°)',
          severity: 'medium',
          shotIndex: i,
        ));
      } else if (normalizedHeadingDiff > 5) {
        totalPenalty += 5.0;
      }

      if (pitchDiff > 20) {
        totalPenalty += 20.0;
        issues.add(QualityIssue(
          category: 'Measurement Consistency',
          description: 'Shot ${i + 1}: Large pitch difference (${pitchDiff.toStringAsFixed(1)}°)',
          severity: 'high',
          shotIndex: i,
        ));
      } else if (pitchDiff > 10) {
        totalPenalty += 10.0;
        issues.add(QualityIssue(
          category: 'Measurement Consistency',
          description: 'Shot ${i + 1}: Moderate pitch difference (${pitchDiff.toStringAsFixed(1)}°)',
          severity: 'medium',
          shotIndex: i,
        ));
      }

      validShots++;
    }

    if (validShots == 0) return 0.0;
    
    // Calculate base penalty from individual shots
    final averagePenalty = totalPenalty / validShots;
    
    // Add penalty based on worst single discrepancy
    double worstDiscrepancyPenalty = 0.0;
    if (maxHeadingDiff > 50) {
      worstDiscrepancyPenalty += 40.0;
    } else if (maxHeadingDiff > 30) {
      worstDiscrepancyPenalty += 25.0;
    } else if (maxHeadingDiff > 15) {
      worstDiscrepancyPenalty += 10.0;
    }

    if (maxPitchDiff > 50) {
      worstDiscrepancyPenalty += 30.0;
    } else if (maxPitchDiff > 30) {
      worstDiscrepancyPenalty += 20.0;
    } else if (maxPitchDiff > 15) {
      worstDiscrepancyPenalty += 8.0;
    }
    
    return max(0.0, 100.0 - averagePenalty - worstDiscrepancyPenalty);
  }

  /// Score length validation (measured vs calculated consistency)
  double _scoreLengthValidation(Section section, List<QualityIssue> issues) {
    if (section.shots.isEmpty) return 100.0;

    int totalShots = 0;
    double totalLengthPenalty = 0.0;
    double maxPercentageDiscrepancy = 0.0;

    for (int i = 0; i < section.shots.length - 1; i++) { // Exclude EOC shot
      final shot = section.shots[i];
      totalShots++;

      if (shot.hasProblematicLength()) {
        final calculatedLength = shot.getCalculatedLength();
        final percentageDiff = ((shot.length - calculatedLength).abs() / shot.length) * 100.0;
        maxPercentageDiscrepancy = max(maxPercentageDiscrepancy, percentageDiff);
        
        issues.add(QualityIssue(
          category: 'Length Validation',
          description: 'Shot ${i + 1}: Measured length (${shot.length.toStringAsFixed(2)}m) vs calculated (${calculatedLength.toStringAsFixed(2)}m)',
          severity: 'high',
          shotIndex: i,
        ));
        // Heavy penalty for problematic shots
        totalLengthPenalty += 50.0;
      } else {
        // For valid shots, calculate length from inclination and depth change
        final depthChange = shot.getDepthChange();
        if (depthChange > 0 && shot.length > 0) {
          // Use average inclination from pitchIn and pitchOut (in degrees/10)
          final avgPitch = (shot.pitchIn + shot.pitchOut) / 2.0 / 10.0; // Convert to degrees
          final radians = avgPitch * pi / 180.0; // Convert to radians
          
          double calculatedLength;
          if (cos(radians).abs() < 0.1) {
            // Near vertical (90 degrees), use depth change as length
            calculatedLength = depthChange;
          } else {
            // Calculate length using trigonometry: length = depth_change / sin(inclination)
            calculatedLength = depthChange / sin(radians).abs();
          }
          
          // Compare measured vs calculated length
          final lengthDifference = (shot.length - calculatedLength).abs();
          final percentageDifference = (lengthDifference / shot.length) * 100.0;
          
          // Track maximum discrepancy
          maxPercentageDiscrepancy = max(maxPercentageDiscrepancy, percentageDifference);
          
          if (percentageDifference > 20.0) {
            totalLengthPenalty += 25.0;
            issues.add(QualityIssue(
              category: 'Length Validation',
              description: 'Shot ${i + 1}: Large length discrepancy (${percentageDifference.toStringAsFixed(1)}%) - measured: ${shot.length.toStringAsFixed(2)}m, calculated: ${calculatedLength.toStringAsFixed(2)}m',
              severity: 'high',
              shotIndex: i,
            ));
          } else if (percentageDifference > 10.0) {
            totalLengthPenalty += 15.0;
            issues.add(QualityIssue(
              category: 'Length Validation',
              description: 'Shot ${i + 1}: Moderate length discrepancy (${percentageDifference.toStringAsFixed(1)}%) - measured: ${shot.length.toStringAsFixed(2)}m, calculated: ${calculatedLength.toStringAsFixed(2)}m',
              severity: 'medium',
              shotIndex: i,
            ));
          } else if (percentageDifference > 5.0) {
            totalLengthPenalty += 5.0;
            issues.add(QualityIssue(
              category: 'Length Validation',
              description: 'Shot ${i + 1}: Minor length discrepancy (${percentageDifference.toStringAsFixed(1)}%)',
              severity: 'low',
              shotIndex: i,
            ));
          }
        }
      }
    }

    if (totalShots == 0) return 100.0;

    // Calculate base penalty from individual shots
    final averagePenalty = totalLengthPenalty / totalShots;
    
    // Add penalty based on worst single length discrepancy
    double worstLengthPenalty = 0.0;
    if (maxPercentageDiscrepancy > 80.0) {
      worstLengthPenalty += 50.0;
    } else if (maxPercentageDiscrepancy > 50.0) {
      worstLengthPenalty += 35.0;
    } else if (maxPercentageDiscrepancy > 30.0) {
      worstLengthPenalty += 20.0;
    } else if (maxPercentageDiscrepancy > 15.0) {
      worstLengthPenalty += 10.0;
    }

    return max(0.0, 100.0 - averagePenalty - worstLengthPenalty);
  }

  /// Score data completeness (missing values, LRUD presence)
  double _scoreDataCompleteness(Section section, List<QualityIssue> issues) {
    if (section.shots.isEmpty) return 0.0;

    double score = 100.0;
    int validShots = 0;
    int shotsWithLRUD = 0;
    int shotsWithTemperature = 0;

    for (int i = 0; i < section.shots.length - 1; i++) { // Exclude EOC shot
      final shot = section.shots[i];
      validShots++;

      // Check for zero/invalid core measurements
      if (shot.length <= 0) {
        score -= 20.0;
        issues.add(QualityIssue(
          category: 'Data Completeness',
          description: 'Shot ${i + 1}: Missing or zero length measurement',
          severity: 'high',
          shotIndex: i,
        ));
      }

      if (shot.headingIn == 0 && shot.headingOut == 0) {
        score -= 15.0;
        issues.add(QualityIssue(
          category: 'Data Completeness',
          description: 'Shot ${i + 1}: Missing heading measurements',
          severity: 'medium',
          shotIndex: i,
        ));
      }

      // Check LRUD completeness (bonus scoring)
      if (shot.left > 0 || shot.right > 0 || shot.up > 0 || shot.down > 0) {
        shotsWithLRUD++;
      }

      // Check temperature readings (bonus scoring)
      if (shot.temperature != 0) {
        shotsWithTemperature++;
      }
    }

    if (validShots == 0) return 0.0;

    // Bonus points for LRUD and temperature data
    final lrudBonus = (shotsWithLRUD / validShots) * 10.0;
    final temperatureBonus = (shotsWithTemperature / validShots) * 5.0;

    return max(0.0, min(100.0, score + lrudBonus + temperatureBonus));
  }

  /// Convert numerical score (0-100) to star rating (1-5)
  int _scoreToStars(double score) {
    if (score >= 90) return 5;
    if (score >= 75) return 4;
    if (score >= 60) return 3;
    if (score >= 40) return 2;
    return 1;
  }
}