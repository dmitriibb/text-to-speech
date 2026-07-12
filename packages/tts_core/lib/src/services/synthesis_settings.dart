const double speechSpeedMin = 0.5;
const double speechSpeedDefault = 1.0;
const double speechSpeedMax = 2.0;
const int speechSpeedDivisions = 15;

const int dialogVolumeMin = 1;
const int dialogVolumeDefault = 7;
const int dialogVolumeMax = 10;

double clampSpeechSpeed(double speed) {
  if (speed.isNaN) {
    return speechSpeedDefault;
  }

  return speed.clamp(speechSpeedMin, speechSpeedMax).toDouble();
}

int clampDialogVolume(int volume) {
  return volume.clamp(dialogVolumeMin, dialogVolumeMax).toInt();
}

double dialogVolumeToGain(int volume) {
  return clampDialogVolume(volume) / dialogVolumeDefault;
}
