# Model Expansion

## Goal

Document the current open/free desktop-appropriate TTS model options and expand the app catalog/runtime to support additional desktop models.

## Current Status

Complete. Research identified low-risk sherpa-friendly additions and higher-risk advanced candidates, and the repo now includes the immediate targets:

- add a multilingual Kokoro entry with Chinese + English support
- add KittenTTS Mini support to the desktop/shared runtime
- capture the research in a root-level `models.list.md`

## Notes

- Multilingual Kokoro in sherpa-onnx is not the same packaging as the current English-only Kokoro entry; it needs multiple lexicon files and Chinese rule FST assets.
- KittenTTS Mini is a separate sherpa-supported model family and needs runtime handling in `tts_core`, not just a catalog entry.
- Licensing remains local-validation-first until redistribution evidence is captured in `docs/licensing.md`.

## Outcome

1. Extended `VoiceModel`, task payload handling, validation, and `TtsService` to support multilingual Kokoro runtime assets and the `kitten` model family.
2. Added `kokoro-multi-lang-v1_0` and `kitten-mini-en-v0_1-fp16` to the shared model catalog and both app asset copies.
3. Recorded the research summary, packaging notes, and Kokoro language guidance in `models.list.md`.
4. Updated licensing and domain-brain docs so future work knows why multilingual Kokoro needs extra helper assets.
