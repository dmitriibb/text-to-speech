# Kokoro Model Support (Extended – Desktop Only)

## Goal

Add Kokoro TTS model support to the desktop app so users can generate higher-quality, multi-speaker speech. This is the foundation for the remaining Extended features (voice tuning, voice cloning).

## Current Status

Not started.

## Context

- `TtsService.loadModel()` currently only builds `OfflineTtsVitsModelConfig`. Kokoro requires `OfflineTtsKokoroModelConfig` (different config path in sherpa_onnx).
- The `VoiceModel.family` field already exists (`"vits"` today). Kokoro models will use `"kokoro"`.
- The `provider` field flows through to `OfflineTtsModelConfig.provider` — no changes needed there.
- Kokoro models include a `voices.bin` file and support multiple speaker styles. VITS models do not.
- sherpa_onnx ^1.12.35 is in use. Kokoro config support was added around 1.11.x.

## Scope

### In Scope

1. **TtsService multi-family routing** — route `loadModel()` through VITS or Kokoro config based on `VoiceModel.family`. Add `voicesFile` field to `VoiceModel` for Kokoro's `voices.bin`.
2. **Kokoro model catalog entries** — add at least one Kokoro model to `approved_models.json` (e.g., `kokoro-en-v0_19`). Include the archive URL, model/tokens/voices files, and default speaker ID.
3. **Model download and extraction** — verify the existing download + extraction pipeline handles Kokoro archives (they may be larger or have different directory layout).
4. **Desktop integration** — Kokoro models appear in the voice dropdown alongside VITS models. Selecting a Kokoro model loads it via the Kokoro config path. Synthesis works end-to-end.
5. **Background task executor** — verify `DesktopTaskExecutor` handles Kokoro model loading and synthesis (the `_voiceModelFromPayload()` must round-trip the new fields).

### Out of Scope

- Multi-speaker UI (task 8).
- GPU acceleration (task 7).
- Mobile app support (Kokoro models may be too large for mobile).

## Implementation Steps

1. Add `voicesFile` field to `VoiceModel` (default empty string, like `lexiconFile`).
2. Update `VoiceModel.fromJson()` / `toJson()` and `toMap()` / factory to handle the new field.
3. In `TtsService.loadModel()`, branch on `model.family`:
   - `"vits"` → existing `OfflineTtsVitsModelConfig` path.
   - `"kokoro"` → new `OfflineTtsKokoroModelConfig` with `model`, `voices`, `tokens`, `dataDir`.
4. Add a Kokoro entry to `approved_models.json` with correct file paths.
5. Update `_voiceModelFromPayload()` in both `DesktopTaskExecutor` and `LongRunningTaskHandler` to include `voicesFile`.
6. Test: install Kokoro model → select it → generate speech → verify playback.

## Blockers

- Need to confirm exact Kokoro model archive URL and file layout from sherpa-onnx pretrained models page.
- Need to verify sherpa_onnx ^1.12.35 includes the Kokoro Dart API surface.

## Next Steps

Start with step 1 (add `voicesFile` to `VoiceModel`).
