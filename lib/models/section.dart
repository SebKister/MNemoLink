import 'dart:math';
import 'shot.dart';
import 'enums.dart';

/// Represents a section of a cave survey containing multiple shots
class Section {
  SurveyDirection direction;
  List<Shot> shots;
  String name;
  DateTime dateSurvey;
  bool brokenFlag;

  /// Default constructor
  Section({
    this.direction = SurveyDirection.surveyIn,
    List<Shot>? shots,
    this.name = "",
    DateTime? dateSurvey,
    this.brokenFlag = false,
  }) : shots = shots ?? <Shot>[],
       dateSurvey = dateSurvey ?? DateTime.now();

  /// Calculate total length of all shots in this section
  double get length {
    if (shots.isEmpty) return 0.0;
    
    double segmentLength = 0.0;
    for (final shot in shots) {
      segmentLength += shot.length;
    }
    return segmentLength;
  }

  /// Get the starting depth (first shot's depth in)
  double get depthStart {
    return shots.isNotEmpty ? shots.first.depthIn : 0.0;
  }

  /// Get the ending depth (second-to-last shot's depth out, excluding EOC)
  double get depthEnd {
    return shots.length >= 2 ? shots[shots.length - 2].depthOut : 0.0;
  }

  /// Get the minimum depth in this section
  double get depthMin {
    if (shots.isEmpty) return 0.0;
    
    double minDepth = double.infinity;
    
    // Exclude the last shot (EOC) which has all zeros
    for (int i = 0; i < shots.length - 1; i++) {
      minDepth = min(minDepth, shots[i].depthIn);
      minDepth = min(minDepth, shots[i].depthOut);
    }
    
    return minDepth == double.infinity ? 0.0 : minDepth;
  }

  /// Get the maximum depth in this section
  double get depthMax {
    if (shots.isEmpty) return 0.0;
    
    double maxDepth = double.negativeInfinity;
    
    // Exclude the last shot (EOC) which has all zeros
    for (int i = 0; i < shots.length - 1; i++) {
      maxDepth = max(maxDepth, shots[i].depthIn);
      maxDepth = max(maxDepth, shots[i].depthOut);
    }
    
    return maxDepth == double.negativeInfinity ? 0.0 : maxDepth;
  }

  // Legacy getters/setters for compatibility with existing code
  SurveyDirection getDirection() => direction;
  void setDirection(SurveyDirection newDirection) => direction = newDirection;
  
  List<Shot> getShots() => shots;
  void setShots(List<Shot> newShots) => shots = newShots;
  
  String getName() => name;
  void setName(String newName) => name = newName;
  
  DateTime getDateSurvey() => dateSurvey;
  void setDateSurvey(DateTime newDateSurvey) => dateSurvey = newDateSurvey;
  
  bool getBrokenFlag() => brokenFlag;
  void setBrokenFlag(bool flag) => brokenFlag = flag;
  
  double getLength() => length;
  double getDepthStart() => depthStart;
  double getDepthEnd() => depthEnd;
  double getDepthMin() => depthMin;
  double getDepthMax() => depthMax;
}