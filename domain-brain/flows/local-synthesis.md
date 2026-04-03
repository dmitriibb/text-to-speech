# Local Synthesis Flow

## Goal

Generate understandable speech locally from user-provided text with no cloud dependency.

## Steps

1. User enters text and chooses a ready voice plus speed.
2. App validates that text is non-empty.
3. App loads the selected model into `sherpa-onnx` if needed.
4. `TtsService` generates audio samples locally.
5. App writes those samples to a local `.wav` file.
6. App updates synthesis state and exposes the generated audio to playback or output actions.

## Invariants

- Synthesis requires a selected ready model.
- Synthesis requires non-empty text.
- Output is written to `.wav` before playback, export, or sharing.
- After install, synthesis works offline.

## Failure Modes

- no ready model selected
- empty input text
- model load failure
- runtime synthesis error
- `.wav` file write failure