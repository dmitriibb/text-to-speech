# Live TTS Streaming On Main Screen

## Goal

Add a `Live` mode on the Main screen for both desktop and Android. In live mode, the text input grows, shows a vertical scrollbar, exposes a play/stop control and chunk-size input, splits text into sentence-safe chunks, pre-generates upcoming chunks, and highlights current generation/playback state inside the text editor.

## Current Status

Implemented in shared core/UI plus both app states. Targeted package tests pass, and app analysis only reports pre-existing unrelated issues outside this feature.

## Scope

1. Add a `Live` toggle above the main text input.
2. Add a chunk-size words parameter with default `10`.
3. Split input into chunk-sized word groups, rounding each chunk up to the end of the current sentence.
4. Generate live chunks ahead of playback so one chunk can play while later chunks are already ready or generating.
5. Highlight the currently playing, next ready, and generating chunks in the text input.
6. Wire the feature into both desktop and Android home screens.

## Notes

- This is Basic functionality, so the chunking/session logic belongs in `packages/tts_core/` and the reusable editor UI belongs in `packages/shared_ui/`.
- Existing generated-audio task list behavior should stay intact for normal non-live synthesis.

## Next Steps

1. Validate the live playback UX manually on desktop and Android devices or emulators.
2. Decide whether finished live sessions should optionally persist a merged final WAV in a future task.
