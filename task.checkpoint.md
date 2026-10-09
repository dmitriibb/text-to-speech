# Task Checkpoints

## 2026-07-12 — Generic reusable model settings

Status: implemented and verified on desktop and Android.

### What changed

- Replaced screen-owned model/voice settings UI with the shared `ModelSelector` from `packages/shared_ui/lib/src/widgets/model_selector.dart`.
- `ModelSelector` combines an installed-model dropdown with a gear button. The gear opens one capability-driven modal instead of requiring each screen to implement its own controls.
- Every model receives volume (`0.5`–`1.5`, default `1.0`) and speed (`0.5`–`2.0`).
- Speaker and generation-language dropdowns appear only when the selected `VoiceModel` declares those capabilities.
- Added `ModelSynthesisSettings` in `packages/tts_core/lib/src/models/model_synthesis_settings.dart` for volume, speed, speaker ID, language, and JSON-safe model-family extension values.
- Settings are normalized against current model capabilities when loaded, so removed speakers/languages and invalid numeric values fall back safely.
- Normal synthesis and Live TTS now pass the selected volume gain through the task payload; the isolate scales generated samples before writing the WAV.
- Dialog speaker rows now reuse `ModelSelector` instead of maintaining separate model, speaker, language, and volume widgets.
- Removed the obsolete shared `VoiceSettingsControls` implementation.

### Per-model state and persistence

- Both apps keep settings in a map keyed by stable `VoiceModel.id`.
- Switching models restores that model's saved volume, speed, speaker, and language.
- Desktop persists the map in `.tts_model_settings.json` under the user profile.
- Android persists the map in `model_settings.json` beside its existing app-private settings file.
- Applying changed settings stops an active Live TTS session, preventing already-buffered audio from continuing with stale settings.

### Android integration

- Home: `apps/android_app/lib/widgets/settings_panel.dart` uses `ModelSelector`.
- Live TTS: `apps/android_app/lib/widgets/live_tts_panel.dart` shows the selector above the live editor and disables model switching while streaming.
- Dialog: `packages/shared_ui/lib/src/widgets/dialog_mode_panel.dart`, consumed by Android's Dialog screen, uses the same selector and modal for each speaker assignment.
- State: `apps/android_app/lib/state/app_state.dart` loads, validates, applies, and saves per-model settings.
- Runtime: Android normal and live synthesis pass model volume, speed, speaker ID, and generation language to the shared synthesis services.

### Desktop backend refactor

- Removed the Voice Lab screen and its dedicated file-selector dependency.
- Added `Backend models`, limited to enabling OpenVoice/OmniVoice, configuring server URLs, and checking connection health.
- Backend enabled state and URLs persist across launches.
- Model-family controls such as cloning-file selection or style presets can be injected into `ModelSelector` through its extension builder without modifying Home, Live TTS, or Dialog.

### Verification

- `packages/tts_core`: all tests passed.
- `packages/shared_ui`: all tests passed.
- `apps/desktop_app`: all tests passed.
- `apps/android_app`: all tests passed.
- Analyzer passed across both apps and both shared packages with no findings.

## Checkpoint 2

- Fixed Live-mode playback ordering in the shared `LiveTtsSession`.
- Later chunks that synthesize first now wait for the earliest unplayed chunk.
- Added a regression test covering out-of-order concurrent generation.
- Updated the domain edge case to require strict text-order playback.
- Formatting and `git diff --check` passed; Flutter tests hung before execution in this environment.

## Checkpoint 3

- Completed Russian phone-call planning on 2026-10-09; six linked advanced-planning files are in `tasks/phone-call-audio/`.
- Recorded the recommended clean conversation export plus free Audacity phone-effect workflow; AMD acceleration remains second priority.
- Identified backend Dialog routing, independent actor profiles, and complete conversation rendering as implementation gaps.
- Researched official Russian model and RX 9070 XT Windows/WSL support; real synthesis and GPU compatibility remain untested.
- Validated plan markers, flat checklists, and local links; archived the completed planning task as task 24.

## Checkpoint 4

- Implemented D1 Russian fixtures/rubric, bounded pinned-runtime evaluation, hashed reference reuse, and clean/phone listening previews.
- Real VoxCPM2 CPU runs produced 20 two-actor and six three-actor turns; listening/voice acceptance and M1 remain open.
- Fixed pinned API seed handling, serialized inference, disabled default normalization, and rejected unsupported speeds.
- Shared import diagnostics preserve Russian text and expose skipped rows/errors on desktop and Android.
- Backend venv upgraded to CPython 3.10.22; its ignored base interpreter must be retained or the venv recreated.
- All 93 tests and analysis across both apps/shared packages passed; measured results and remaining work saved with active task 25.

## Checkpoint 5

- Completed D3: shared local/backend target contracts and versioned independent actor settings/reference history.
- Both apps now use actor-owned speed, exact gain and extensions; edits preserve other actors and Home/Live defaults.
- Added bounded managed WAV-reference copies with SHA-256 reuse and missing/changed-file rejection before upload.
- Actor JSON round-trips and nested settings isolation are tested; project persistence UI and reference pickers remain open.
- All 84 Flutter tests and analysis across both apps/shared packages passed; formatting and diff checks passed.
- D2 listening acceptance deferred per user; next D4 uses provisional VoxCPM2. Backend routing, complete lifecycle and rendering remain open.

## Checkpoint 6

- Completed Russian-dialog engineering; archived task 25 and supplied the testing guide.
- Both apps share editable persisted projects, safe selective generation/retry, timing and streamed conversation rendering.
- Desktop routes pinned VoxCPM2 references with truthful controls and bounded cancellation/cleanup.
- Real three-actor CPU inference/retry/reload/render and Audacity 3.7.7 export/reopen passed; clean input preserved.
- Passed 115 automated tests plus real inference; four analyzers clean and ten-minute rendering covered.
- Android APK built with Java 17; Windows native build needs Visual Studio C++.
- Voice/listening/device acceptance remains user testing; AMD and task 19 Home/German scope remain separate.
