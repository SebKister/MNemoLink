 class Shot {

   TypeShot typeShot=TypeShot.STD;

  /// Get the value of typeShot
  ///
  /// @return the value of typeShot
   TypeShot getTypeShot() {
    return typeShot;
  }

  /// Set the value of typeShot
  ///
  /// @param typeShot new value of typeShot
   void setTypeShot(TypeShot typeShot) {
    this.typeShot = typeShot;
  }

   double length=0.0;

  /// Get the value of length
  ///
  /// @return the value of length
   double getLength() {
    return length;
  }

  /// Set the value of length
  ///
  /// @param length new value of length
   void setLength(double length) {
    this.length = length;
  }

   int headingIn=0;
   int headingOut=0;

   int pitchIn=0;

   int pitchOut=0;

   int markerIndex=0;

  /// Get the value of markerIndex
  ///
  /// @return the value of markerIndex
   int getMarkerIndex() {
    return markerIndex;
  }

  /// Set the value of markerIndex
  ///
  /// @param markerIndex new value of markerIndex
   void setMarkerIndex(int markerIndex) {
    this.markerIndex = markerIndex;
  }

  /// Get the value of pitchOut
  ///
  /// @return the value of pitchOut
   int getPitchOut() {
    return pitchOut;
  }

  /// Set the value of pitchOut
  ///
  /// @param pitchOut new value of pitchOut
   void setPitchOut(int pitchOut) {
    this.pitchOut = pitchOut;
  }

  /// Get the value of pitchIn
  ///
  /// @return the value of pitchIn
   int getPitchIn() {
    return pitchIn;
  }

  /// Set the value of pitchIn
  ///
  /// @param pitchIn new value of pitchIn
   void setPitchIn(int pitchIn) {
    this.pitchIn = pitchIn;
  }

   int getHeadingOut() {
    return headingOut;
  }

   void setHeadingOut(int headingOut) {
    this.headingOut = headingOut;
  }

   int getHeadingIn() {
    return headingIn;
  }

   void setHeadingIn(int headingIn) {
    this.headingIn = headingIn;
  }

   double depthIn=0;

  /// Get the value of depthIn
  ///
  /// @return the value of depthIn
   double getDepthIn() {
    return depthIn;
  }

  /// Set the value of depthIn
  ///
  /// @param depthIn new value of depthIn
   void setDepthIn(double depthIn) {
    this.depthIn = depthIn;
  }

   double depthOut=0;

  /// Get the value of depthOut
  ///
  /// @return the value of depthOut
   double getDepthOut() {
    return depthOut;
  }

  /// Set the value of depthOut
  ///
  /// @param depthOut new value of depthOut
   void setDepthOut(double depthOut) {
    this.depthOut = depthOut;
  }

   Shot(this.typeShot, this.length, this.headingIn, this.headingOut, this.depthIn, this.depthOut);

  Shot.zero(){
    length = 0;
    headingIn = 0;
    headingOut = 0;
    depthIn = 0;
    depthOut = 0;
    typeShot=TypeShot.STD;
  }
}


 enum SurveyDirection {
  SURVEY_IN,SURVEY_OUT
}

 enum TypeShot {
  CSA, CSB, STD, EOC
}

enum UnitType{
  METRIC,IMPERIAL
}