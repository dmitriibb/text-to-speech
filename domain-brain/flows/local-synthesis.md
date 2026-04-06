# Local Synthesis Flow

## Goal

Generate understandable speech locally from user-provided text with no cloud dependency.

## Steps

1. User enters text and chooses a ready voice plus speed, and for multi-speaker models also chooses a speaker.
2. When enough per-model history exists, the basic UI shows expected generation time and expected audio length for the current text.
3. App validates that text is non-empty.
4. The app queues long-running voice-load or synthesis work in the shared isolate task executor instead of blocking the UI isolate.
5. The task runner loads the selected model into `sherpa-onnx` if needed.
6. `TtsService` generates audio samples locally in the background task isolate.
7. Pocket TTS normal synthesis uses the model's bundled default reference clip when voice cloning is not active, so regular generation still produces speech.
8. The background task writes those samples to a local `.wav` file.
9. App state receives task updates, exposes active tasks in the UI, and surfaces the generated audio for playback or output actions.

## Invariants

- Synthesis requires a selected ready model.
- Synthesis requires non-empty text.
- Multi-speaker models expose the same speaker-selection control on desktop and Android.
- Basic text input can show expected generation and output durations only when stats exist for the selected model and the current text length is non-zero.
- Output is written to `.wav` before playback, export, or sharing.
- After install, synthesis works offline.
- Pocket TTS requires either the bundled default reference clip or a user-supplied cloning clip before it can generate audio.
- Android model loading and synthesis must not block the main Flutter UI isolate.
- Long-running tasks must stay visible in the UI with a short label, elapsed time, and cancel affordance.
- Long-running task lists show the most recently created task first so new work stays visible without scrolling.

## Failure Modes

- no ready model selected
- empty input text
- model load failure
- model load or generation finishes after the user has already requested cancellation
- runtime synthesis error
- Pocket TTS bundled reference clip missing from an installed model directory
- `.wav` file write failure
