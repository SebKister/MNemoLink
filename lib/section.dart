import './shot.dart';

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
}
