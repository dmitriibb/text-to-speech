# Voice Tuning Controls (Extended – Desktop Only)

## Goal

Give the desktop user controls to select different speaker voices and adjust style/expression parameters for multi-speaker models (primarily Kokoro).

## Current Status

Complete.

## What Was Done

1. Added `Speaker` class and `speakers` field to `VoiceModel` in tts_core (parsed from catalog JSON `speakers` array).
2. Added 11 Kokoro speakers (AF, AF Bella, AF Nicole, AF Sarah, AF Sky, AM Adam, AM Michael, BF Emma, BF Isabella, BM George, BM Lewis) to `approved_models.json` and synced to both app assets.
3. Added `selectedSpeakerId` + `setSpeakerId()` to desktop `AppState`. Resets on model change. Passed through to `submitSynthesis()`.
4. Added speaker dropdown in `SettingsPanel` — only visible when the selected model has speakers.
5. All tests pass. Both apps analyze clean.

## Context

- Kokoro models ship with multiple speakers/voices in a `voices.bin` file. Each speaker has a name (e.g., `af_heart`, `af_bella`, `am_adam`) and produces a distinct voice.
- sherpa_onnx exposes speaker selection via `speakerId` (integer index) in `OfflineTts.generate()`.
- `TtsService.synthesize()` already accepts `speakerId` and `speed` parameters.
- The current `SettingsPanel` has a speed slider (0.25x–3.0x). No speaker selector exists.
- VITS/Piper models are typically single-speaker, so the speaker selector should only appear when a multi-speaker model is selected.

## Scope

### In Scope

1. **Speaker metadata** — add a `speakers` field to `VoiceModel`: a list of `{id: int, name: String}` entries. VITS models have an empty list (single speaker). Kokoro models list all available speakers.
2. **Speaker selector UI** — add a dropdown in `SettingsPanel` that appears when the selected model has multiple speakers. Shows speaker names, maps selection to `speakerId`.
3. **Style presets** (stretch goal) — if Kokoro supports blending speaker embeddings or style tokens, add preset buttons (e.g., "Calm", "Enthusiastic", "Narrator"). This depends on sherpa_onnx API surface.
4. **Persist selection** — remember the last-used speaker per model.

### Out of Scope

- Voice cloning (task 9).
- Creating new speakers (that's voice cloning territory).
- Mobile support (Extended feature).

## Dependencies

- **Task 6 (Kokoro model support)** must be complete first. Without a multi-speaker model, there's nothing to tune.

## Implementation Steps

1. Add `speakers` field to `VoiceModel`: `List<Map<String, dynamic>>` with `id` (int) and `name` (String). Default: empty list.
2. Update `VoiceModel.fromJson()` and `toMap()` to handle the speakers list.
3. Populate speakers in Kokoro catalog entries (map Kokoro voice names to speaker IDs).
4. Add `selectedSpeakerId` to desktop `AppState`. Default to model's `defaultSpeakerId`.
5. When model selection changes, reset `selectedSpeakerId` to the new model's default.
6. Extend `SettingsPanel`: if `selectedModel.speakers.isNotEmpty`, show a speaker dropdown between voice selector and speed slider.
7. Pass `selectedSpeakerId` through to `taskManager.submitSynthesis()`.
8. Test: select Kokoro model → pick different speakers → generate speech → verify different voices.

## Blockers

- Depends on task 6 (Kokoro model support).
- Need to confirm exact speaker names and IDs for the chosen Kokoro model.

## Next Steps

Wait for task 6 to complete, then start with step 1.
