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
