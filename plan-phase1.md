# Phase 1 Plan: Desktop MVP

Updated: 2026-04-03

## 1. Goal

Phase 1 builds the **first user-facing application** in this monorepo:

- a **desktop app**
- for **Ubuntu and Windows**
- that converts typed or pasted English text into **understandable local speech**
- with **no cloud API dependency**

This phase is complete only when the desktop app can do the basic job reliably on real desktop machines.

## 2. Starting Point

Phase 0 already proved the core local TTS path in this repository:

- local model download works
- local cache reuse works
- local `sherpa-onnx` synthesis works
- `.wav` generation works
- benchmark texts and validation reports exist

Known facts from Phase 0:

- Current validated model: `vits-piper-en_US-lessac-medium`
- Current workspace host validation: passed
- Ubuntu validation: Unknown
- Windows validation: Unknown
- Redistribution-safe default voice for the desktop app: Unknown

Needed to decide the remaining Unknown items:

- Run the app and smoke tests on one Ubuntu reference machine
- Run the app and smoke tests on one Windows reference machine
- Confirm one English voice/model pair that is safe to redistribute

## 3. Definition Of Done

Phase 1 is done when all of the following are true:

- `apps/desktop_app` contains a runnable Flutter desktop app
- the app works on Ubuntu and Windows
- the app can generate understandable English speech locally
- the app can play generated audio inside the app
- the app can save generated audio as `.wav`
- the app supports at least one English voice
- the app supports speed control
- the app works offline after the model has been installed
- missing-model and synthesis-failure states are handled cleanly

## 4. Scope

### In scope

- Desktop Flutter app shell
- Text input
- Generate speech action
- Local model install and detection
- Voice selection for approved local voices
- Speed control
- Audio playback
- `.wav` export
- Error handling
- Basic desktop smoke tests

### Out of scope

- Android app work
- Voice cloning
- Tone or emotion editing
- Fine-tuning models
- Cloud APIs
- GPU-specific optimizations
- Rich document import
- Background batch processing
- Speech history library

## 5. Main Technical Decisions

### Desktop app framework

Use **Flutter desktop** in `apps/desktop_app`.

Reason:

- It matches the monorepo direction from `plan-main.md`
- It keeps the future Android path aligned with the same UI stack
- It is a realistic way to ship both Linux and Windows from one app codebase

### TTS runtime inside the desktop app

Use the **`sherpa_onnx` Flutter package** directly in the desktop app, not the Phase 0 Python harness.

Reason:

- The Phase 0 Python harness was only for validation
- `sherpa_onnx` already exposes Dart/Flutter support for Linux and Windows
- Phase 1 should validate the runtime path that the shipped app will actually use

### Model strategy

Use two model statuses during Phase 1:

1. **Development model**
   - Start with `vits-piper-en_US-lessac-medium`
   - It is already validated locally in Phase 0

2. **Release candidate model**
   - Must be an English voice with acceptable redistribution terms
   - This is currently **Unknown**

Pragmatic rule:

- It is acceptable to develop the desktop app against the current validated model first
- It is not acceptable to publish the desktop MVP until the default bundled or downloadable release voice is legally cleared

### Package boundaries

Avoid over-abstracting too early.

Phase 1 package rule:

- Keep most Phase 1 implementation in `apps/desktop_app`
- Move only stable, clearly reusable logic into `packages/tts_core`
- Do not spend time building Android abstractions before the desktop app works

## 6. Planned User Experience

### First launch

- User opens the desktop app
- App checks whether a local model is available
- If no model is present, app shows a clear install/download action
- App shows model status, storage location, and basic progress

### Main workflow

- User pastes or types English text
- User chooses a voice
- User adjusts speed
- User clicks `Generate`
- App produces audio locally
- User can play the audio
- User can save the result as `.wav`

### Failure workflow

- Missing model: app explains how to install it
- Empty text: app blocks generation and shows validation
- Synthesis failure: app shows an error state and preserves input text
- Save failure: app shows the file error without losing the generated audio in memory

## 7. App Architecture

### UI layer

Lives in `apps/desktop_app`.

Main screens/components:

- Main window
- Text input panel
- Voice and speed settings panel
- Synthesis action bar
- Playback panel
- Save/export action
- Model status banner

### Application layer

Responsible for:

- app state
- input validation
- synthesis job lifecycle
- loading/error/success states
- wiring playback and export actions

### Runtime layer

Responsible for:

- loading the selected model
- invoking `sherpa_onnx`
- returning waveform data and metadata

### File and model layer

Responsible for:

- locating the app data directory
- locating installed models
- reading the model catalog
- downloading or unpacking approved models
- saving `.wav` files

## 8. Recommended Folder Plan

### `apps/desktop_app`

Planned contents:

- Flutter app entrypoint
- desktop UI
- desktop-specific state and services
- packaging config for Linux and Windows

### `packages/tts_core`

Only add code here when it is stable and clearly reusable.

Likely candidates:

- model metadata parsing
- text validation rules
- synthesis request and result models
- shared error types

### `packages/model_catalog`

Continue using this package for:

- approved models
- model status metadata
- license status

## 9. Step Order

### Step 1: Install desktop toolchain

- Install Flutter
- Enable Linux and Windows desktop targets
- Confirm `flutter doctor`
- Confirm a new desktop Flutter app runs locally

Expected result:

- We can build and run a desktop shell before touching TTS code

### Step 2: Create the desktop app shell

- Scaffold `apps/desktop_app`
- Set up basic project structure
- Add a simple main window
- Add a basic state management approach

Expected result:

- A desktop app opens on the target platform

### Step 3: Integrate `sherpa_onnx`

- Add the Flutter package dependency
- Reproduce the Phase 0 synthesis path in Dart
- Validate model loading from a local directory
- Generate one `.wav` from a hardcoded sample

Expected result:

- The desktop app can synthesize audio locally without Python

### Step 4: Add model management

- Detect installed models
- Read approved model metadata from the catalog
- Add a development install path for the validated model
- Show install status in the UI

Expected result:

- The app can explain whether it is ready to synthesize

### Step 5: Build the core user flow

- Add text input
- Add voice selection
- Add speed control
- Add generate button
- Add generation state feedback

Expected result:

- The user can generate audio from their own text

### Step 6: Add playback and export

- Play generated audio in-app
- Add save dialog or explicit export path
- Write valid `.wav` output

Expected result:

- The app is useful without leaving the main screen

### Step 7: Add failure handling and polish

- Empty input validation
- Model missing state
- Runtime failure state
- Save/export failure state
- Prevent double-submit during synthesis

Expected result:

- The app is stable enough for repeated manual testing

### Step 8: Run cross-platform smoke tests

- Linux smoke test
- Windows smoke test
- Generate, play, and save on both platforms
- Record blockers and platform-specific fixes

Expected result:

- We know whether the MVP really works on both target desktop platforms

## 10. Testing Plan

### Automated tests

- unit tests for catalog parsing
- unit tests for input validation
- unit tests for synthesis state transitions
- widget tests for basic UI flows where practical

### Manual smoke tests

Run these on Linux and Windows:

1. Launch the app
2. Install or detect the model
3. Generate speech from a short sentence
4. Generate speech from a medium paragraph
5. Change speed and generate again
6. Save `.wav`
7. Restart the app and confirm the model is still detected

### Performance checks

Target:

- generation should be comfortably usable on CPU-only hardware

Unknown:

- exact pass/fail latency threshold on the final reference Windows and Ubuntu machines

Needed to decide:

- choose at least one Windows reference machine
- choose at least one Ubuntu reference machine
- record acceptable generation latency and memory use for those machines

## 11. Deliverables

Phase 1 should produce:

- a runnable desktop app in `apps/desktop_app`
- updated docs for setup and local run instructions
- a clear model-install workflow
- at least one verified local synthesis path inside the app
- Linux and Windows smoke-test notes

## 12. Known And Accepted Limitations

- English only
- basic local voice selection only
- CPU-first operation
- no voice cloning
- no style or emotion tuning
- no mobile work yet
- long text handling may still be basic in the MVP

## 13. Main Risks

### Risk: Flutter desktop toolchain friction

Mitigation:

- validate the shell first before integrating TTS

### Risk: Desktop playback package issues

Status: Unknown

Needed to decide:

- test one desktop-safe audio playback package during implementation

### Risk: Model redistribution status

Status: Not resolved

Mitigation:

- separate development model choice from release model choice
- do not treat legal review as a later cleanup item

### Risk: Windows-specific runtime differences

Status: Unknown

Mitigation:

- run Windows smoke tests before calling Phase 1 complete

## 14. Explicit Unknowns

Unknown:

- final release-safe English default voice
- exact desktop audio playback package choice
- preferred Windows installer format
- preferred Linux distribution format
- final acceptable latency threshold on reference hardware

Needed to decide:

- one redistributable English voice/model pair
- one audio playback implementation that works on Linux and Windows
- target packaging format for early distribution
- reference hardware for Windows and Ubuntu acceptance testing

## 15. Recommended First Implementation Slice

The first Phase 1 implementation slice should be:

1. Install Flutter and confirm desktop targets work
2. Scaffold `apps/desktop_app`
3. Add `sherpa_onnx`
4. Load the already validated development model from the workspace
5. Generate one sample `.wav` from a button click

Reason:

- This is the shortest path from the proven Phase 0 backend to the first real desktop app milestone

## 16. Source Notes Used For This Plan

Current repo files:

- `plan-main.md`
- `docs/architecture.md`
- `docs/validation.md`
- `packages/model_catalog/approved_models.json`

Official sources checked on 2026-04-03:

- Flutter desktop support: https://docs.flutter.dev/platform-integration/desktop
- `sherpa_onnx` Flutter package: https://pub.dev/packages/sherpa_onnx
- `sherpa-onnx` repository and platform support: https://github.com/k2-fsa/sherpa-onnx
- `sherpa-onnx` TTS docs: https://k2-fsa.github.io/sherpa/onnx/tts/index.html
- `sherpa-onnx` Windows install docs: https://k2-fsa.github.io/sherpa/onnx/install/windows.html
