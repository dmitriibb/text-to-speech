const double speechSpeedMin = 0.5;
const double speechSpeedDefault = 1.0;
const double speechSpeedMax = 2.0;
const int speechSpeedDivisions = 15;

double clampSpeechSpeed(double speed) {
  if (speed.isNaN) {
    return speechSpeedDefault;
  }

  return speed.clamp(speechSpeedMin, speechSpeedMax).toDouble();
}
