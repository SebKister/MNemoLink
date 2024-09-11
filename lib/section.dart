import './shot.dart';
import 'dart:math';

class Section {
  Section() {
    shots = [];
  }

  SurveyDirection direction = SurveyDirection.surveyIn;

  /// Get the value of direction
  ///
  /// @return the value of direction
  SurveyDirection getDirection() {
    return direction;
  }

  /// Set the value of direction
  ///
  /// @param direction new value of direction
  void setDirection(SurveyDirection direction) {
    this.direction = direction;
  }

  List<Shot> shots = [];

  /// Get the value of shots
  ///
  /// @return the value of shots
  List<Shot> getShots() {
    return shots;
  }

  /// Set the value of shots
  ///
  /// @param shots new value of shots
  void setShots(List<Shot> shots) {
    this.shots = shots;
  }

  String name = "";

  /// Get the value of name
  ///
  /// @return the value of name
  String getName() {
    return name;
  }

  /// Set the value of name
  ///
  /// @param name new value of name
  void setName(String name) {
    this.name = name;
  }

  DateTime dateSurvey = DateTime.now();

  /// Get the value of dateSurvey
  ///
  /// @return the value of dateSurvey
  DateTime getDateSurvey() {
    return dateSurvey;
  }

  /// Set the value of dateSurvey
  ///
  /// @param dateSurvey new value of dateSurvey
  void setDateSurvey(DateTime newDateSurvey) {
    dateSurvey = newDateSurvey;
  }

  /// Was this segment broken and had to be forcefuly recovered? 
  bool brokenFlag = false; 

  void setBrokenFlag  (bool flag) { 
    brokenFlag = flag;
  }

  bool getBrokenFlag () { 
    return brokenFlag;
  }

  /// Total expanded lenght of the segment 
  double getLength() { 
    double segmentLenght = 0; 

    if  (shots.isNotEmpty) {
      for (int i = 0; i < shots.length; i++) { 
        segmentLenght += shots[i].getLength();
      }
    }
    return segmentLenght; 
  }

  /// Depths (start, min, max, end)
  double getDepthStart() {
    return shots.isNotEmpty ? shots.first.getDepthIn() : 0; 
  }

  double getDepthEnd() { 
    return shots.length >= 2 ? shots[shots.length -2].getDepthOut() : 0;
  }

  double getDepthMin() { 
    double minDepth = 9999; 

    if (shots.isNotEmpty) {
      for (int i = 0; i < shots.length-1; i++) { // last shot is .eoc, with all 0s
        minDepth = min (minDepth, shots[i].getDepthIn()); 
        minDepth = min (minDepth, shots[i].getDepthOut());
      }
    }

    return minDepth; 
  }

  double getDepthMax() { 
    double maxDepth = -1; 

    if (shots.isNotEmpty) { 
      for (int i = 0; i < shots.length-1; i++) { // last shot is .eoc, with all 0s
        maxDepth = max (maxDepth, shots[i].getDepthIn()); 
        maxDepth = max (maxDepth, shots[i].getDepthOut());
      }
    }

    return maxDepth; 
  }
}
