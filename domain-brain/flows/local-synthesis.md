# Local Synthesis Flow

## Goal

Generate understandable speech locally from user-provided text with no cloud dependency.

## Steps

1. User enters text and chooses a ready voice plus speed.
2. App validates that text is non-empty.
3. The app queues long-running voice-load or synthesis work in the shared isolate task executor instead of blocking the UI isolate.
4. The task runner loads the selected model into `sherpa-onnx` if needed.
5. `TtsService` generates audio samples locally in the background task isolate.
6. Pocket TTS normal synthesis uses the model's bundled default reference clip when voice cloning is not active, so regular generation still produces speech.
7. The background task writes those samples to a local `.wav` file.
8. App state receives task updates, exposes active tasks in the UI, and surfaces the generated audio for playback or output actions.

## Invariants

- Synthesis requires a selected ready model.
- Synthesis requires non-empty text.
- Output is written to `.wav` before playback, export, or sharing.
- After install, synthesis works offline.
- Pocket TTS requires either the bundled default reference clip or a user-supplied cloning clip before it can generate audio.
- Android model loading and synthesis must not block the main Flutter UI isolate.
- Long-running tasks must stay visible in the UI with a short label, elapsed time, and cancel affordance.

## Failure Modes

- no ready model selected
- empty input text
- model load failure
- model load or generation finishes after the user has already requested cancellation
- runtime synthesis error
- Pocket TTS bundled reference clip missing from an installed model directory
- `.wav` file write failure
