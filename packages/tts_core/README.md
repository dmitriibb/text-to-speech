# tts_core

Shared Flutter package for the repo's local TTS apps.

## Responsibilities

- parse the approved model catalog JSON
- define shared model metadata types
- validate installed model directories
- extract supported model archive formats in pure Dart
- wrap the shared `sherpa_onnx` offline TTS runtime
- provide basic text-input validation helpers

## Current consumers

- `apps/desktop_app`
- `apps/android_app`
