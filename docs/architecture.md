# Architecture

Updated: 2026-04-03

## Current state

This repository is in **Phase 1**.

What exists now:

- monorepo directory layout
- machine-readable model catalog
- benchmark corpus
- model download and extraction script
- local validation harness for `sherpa-onnx` (Phase 0)
- Flutter desktop app with local TTS synthesis (Phase 1)

## Phase 0 architecture

### Runtime path

1. Download a model from the approved catalog.
2. Extract it into `models/`.
3. Run the Python validation harness.
4. Generate `.wav` files and a JSON report in `artifacts/phase0/`.

### Why the harness is in Python

Flutter and Dart are not required for the validation spike.

The Phase 0 harness uses Python because:

- the official `sherpa-onnx` Python package is documented
- it is quick to automate benchmarking
- it does not lock the future app layer

This is an implementation detail of the validation step, not the final application architecture.

## Phase 1 architecture

### Desktop app (`apps/desktop_app`)

A Flutter desktop app that synthesizes speech locally using `sherpa_onnx`.

Layers:

- **UI layer**: Flutter widgets in `lib/screens/` and `lib/widgets/`
- **State layer**: `ChangeNotifier` in `lib/state/app_state.dart`, wired via `Provider`
- **Service layer**: `TtsService` (sherpa-onnx FFI), `ModelService` (catalog + download), `AudioService` (process-based playback)
- **Data layer**: `VoiceModel` and `InstalledModel` in `lib/models/`

### Runtime path

1. App reads the bundled model catalog (`assets/approved_models.json`)
2. App scans known directories for installed models
3. User types text, selects voice and speed
4. `TtsService` invokes `sherpa_onnx` to generate audio
5. Audio is written to a temp `.wav` file
6. User can play (via system audio tools) or export the `.wav`

### Key dependencies

- `sherpa_onnx` (Flutter plugin) for TTS synthesis
- `provider` for state management
- `http` for model download
- Process-based audio playback (ffplay/aplay on Linux)

## Future phases

- Phase 2: build the Flutter Android app using the same model/runtime foundation
- Phase 3: improve desktop quality and add optional advanced voice features
