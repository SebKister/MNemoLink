// Enums for MNemo survey data types

/// Direction of the survey (inward or outward)
enum SurveyDirection { 
  surveyIn, 
  surveyOut 
}

/// Type of shot measurement
enum TypeShot { 
  csa,  // Compass Shot A
  csb,  // Compass Shot B
  std,  // Standard shot
  eoc   // End of Cave/Section
}

/// Unit system for measurements
enum UnitType { 
  metric, 
  imperial 
}