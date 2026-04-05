# Android Synthesis Playback Layout

## Goal

Fix Android speech generation responsiveness, restore generated-audio playback, and make the task playback controls fit narrow mobile screens.

## Current Status

Complete. Android model preload and speech generation now run through the shared isolate executor instead of the foreground-task runner, task-row export/share uses the selected generated file, and the shared playback controls place play/stop plus export on the first row with the progress bar on the second row for narrow mobile screens.

## Blockers / Unknowns

- Real-device confirmation of the original ANR symptom is still needed because this environment can only provide static validation.

## Verification

- `flutter analyze` in `packages/tts_core`
- `flutter analyze` in `packages/shared_ui`
- `flutter analyze` in `apps/android_app`
- `flutter test` in `packages/tts_core`
- `flutter test` in `apps/android_app`
