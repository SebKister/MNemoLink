class Shot {
  TypeShot typeShot = TypeShot.std;

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

  double length = 0.0;

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

  int headingIn = 0;
  int headingOut = 0;
  int pitchIn = 0;
  int pitchOut = 0;
  int temperature = 0;
  int hr = 0;
  int min = 0;
  int sec = 0;
  int markerIndex = 0;
  double left = 0.0;
  double right = 0.0;
  double up = 0.0;
  double down = 0.0;

  int getHr() {
    return hr;
  }

  void setHr(int hr) {
    this.hr = hr;
  }

  int getMin() {
    return min;
  }

  void setMin(int min) {
    this.min = min;
  }

  int getSec() {
    return sec;
  }

  void setSec(int sec) {
    this.sec = sec;
  }

  int getTemperature() {
    return temperature;
  }

  void setTemperature(int temperature) {
    this.temperature = temperature;
  }

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

  double depthIn = 0;

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

  double depthOut = 0;

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

  Shot(
      this.typeShot,
      this.length,
      this.headingIn,
      this.headingOut,
      this.depthIn,
      this.depthOut,
      this.left,
      this.right,
      this.up,
      this.down,
      this.temperature,
      this.hr,
      this.min,
      this.sec);

  Shot.zero() {
    length = 0;
    headingIn = 0;
    headingOut = 0;
    depthIn = 0;
    depthOut = 0;
    left = 0.0;
    right = 0.0;
    up = 0.0;
    down = 0.0;
    temperature = 0;
    hr = 0;
    min = 0;
    sec = 0;
    typeShot = TypeShot.std;
  }

  void setLeft(double left) {
    this.left = left;
  }

  double getLeft () { 
    return left; 
  }

  void setRight(double right) {
    this.right = right;
  }

  double getRight() { 
    return right;
  }

  void setUp(double up) {
    this.up = up;
  }

  double getUp() { 
    return up; 
  }

  void setDown(double down) {
    this.down = down;
  }

  double getDown() { 
    return down;
  }
}

enum SurveyDirection { surveyIn, surveyOut }

enum TypeShot { csa, csb, std, eoc }

enum UnitType { metric, imperial }
