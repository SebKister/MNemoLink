
/// Represents a quality issue found in survey data
class QualityIssue {
  final String category;
  final String description;
  final String severity; // 'high', 'medium', 'low'
  final int? shotIndex; // Optional shot index if issue is specific to a shot

  QualityIssue({
    required this.category,
    required this.description,
    required this.severity,
    this.shotIndex,
  });
}

/// Represents the overall quality assessment of a survey section
class SurveyQuality {
  final int stars; // 1-5 star rating
  final double score; // 0-100 numerical score
  final List<QualityIssue> issues;
  final Map<String, double> subscores;

  SurveyQuality({
    required this.stars,
    required this.score,
    required this.issues,
    required this.subscores,
  });

  /// Get a formatted tooltip message describing the quality score
  String get tooltipMessage {
    final buffer = StringBuffer();
    buffer.writeln('Survey Quality: $stars/5 stars (${score.toStringAsFixed(1)}/100)');
    buffer.writeln();
    
    // Add subscore breakdown
    subscores.forEach((metric, score) {
      buffer.writeln('${_formatMetricName(metric)}: ${score.toStringAsFixed(1)}/100');
    });
    
    if (issues.isNotEmpty) {
      buffer.writeln();
      
      // Group issues by category
      final issuesByCategory = <String, List<QualityIssue>>{};
      for (final issue in issues) {
        issuesByCategory.putIfAbsent(issue.category, () => []).add(issue);
      }
      
      // Sort categories by impact (based on scoring weights)
      final categoryOrder = ['Measurement Consistency', 'Length Validation', 'Data Completeness'];
      
      for (final category in categoryOrder) {
        if (issuesByCategory.containsKey(category)) {
          final categoryIssues = issuesByCategory[category]!;
          
          // Sort issues by degree of difference or percentage discrepancy (highest first)
          categoryIssues.sort((a, b) {
            final valueA = _extractNumericValue(a.description);
            final valueB = _extractNumericValue(b.description);
            
            // Sort by numeric value descending (highest impact first)
            if (valueA != null && valueB != null) {
              return valueB.compareTo(valueA);
            }
            
            // Fallback to severity sorting if no numeric values found
            final severityOrder = {'high': 0, 'medium': 1, 'low': 2};
            final severityCompare = severityOrder[a.severity]!.compareTo(severityOrder[b.severity]!);
            if (severityCompare != 0) return severityCompare;
            return a.description.compareTo(b.description);
          });
          
          buffer.writeln('$category (${categoryIssues.length} issue${categoryIssues.length == 1 ? '' : 's'}):');
          
          // Show top 3 issues from this category
          final issuesToShow = categoryIssues.take(3);
          for (final issue in issuesToShow) {
            final severityIcon = _getSeverityIcon(issue.severity);
            buffer.writeln('  $severityIcon ${issue.description}');
          }
          
          // Show remaining count if more than 3 issues
          if (categoryIssues.length > 3) {
            buffer.writeln('  • ... and ${categoryIssues.length - 3} more issue${categoryIssues.length - 3 == 1 ? '' : 's'}');
          }
          
          buffer.writeln();
        }
      }
    }
    
    return buffer.toString().trim();
  }
  
  String _getSeverityIcon(String severity) {
    switch (severity) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '•';
    }
  }
  
  /// Extract numeric value from issue description for sorting
  double? _extractNumericValue(String description) {
    // Look for patterns like "45.2°" or "23.4%"
    final degreeMatch = RegExp(r'(\d+\.?\d*)°').firstMatch(description);
    if (degreeMatch != null) {
      return double.tryParse(degreeMatch.group(1)!);
    }
    
    // Look for percentage patterns like "23.4%"
    final percentMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(description);
    if (percentMatch != null) {
      return double.tryParse(percentMatch.group(1)!);
    }
    
    return null;
  }

  String _formatMetricName(String metric) {
    switch (metric) {
      case 'measurement_consistency':
        return 'Angle Consistency';
      case 'length_validation':
        return 'Length Validation';
      case 'data_completeness':
        return 'Data Completeness';
      default:
        return metric.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }
}