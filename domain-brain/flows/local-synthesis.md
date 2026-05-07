# Local Synthesis Flow

## Goal

Generate understandable speech locally from user-provided text with no cloud dependency.

## Steps

1. User enters text and chooses a ready voice plus speed, and for multi-speaker models also chooses a speaker.
2. When enough per-model history exists, the basic UI shows expected generation time and expected audio length for the current text.
3. App validates that text is non-empty.
4. In normal mode, the app queues long-running voice-load or synthesis work in the shared isolate task executor instead of blocking the UI isolate.
5. In live mode, the app starts from the current text caret position, then splits the remaining text into word-target chunks while always rounding each chunk up to the end of the current sentence before generation.
6. Live mode starts generating the earliest pending chunks first, keeps the next chunk ready when possible, and continues generating up to two later chunks in parallel while playback is active.
7. The task runner loads the selected model into `sherpa-onnx` if needed.
8. `TtsService` generates audio samples locally in the background task isolate.
9. Pocket TTS normal synthesis uses the model's bundled default reference clip when voice cloning is not active, so regular generation still produces speech.
10. The background task writes those samples to a local `.wav` file.
11. App state receives task updates, exposes active tasks in the UI, and surfaces the generated audio for playback or output actions.
12. Live mode also highlights generating, next-ready, and currently playing text chunks directly inside the shared editor.

## Invariants

- Synthesis requires a selected ready model.
- Synthesis requires non-empty text.
- Multi-speaker models expose the same speaker-selection control on desktop and Android.
- Basic text input can show expected generation and output durations only when stats exist for the selected model and the current text length is non-zero.
- Output is written to `.wav` before playback, export, or sharing.
- Live mode chunking must preserve sentence boundaries by extending a chunk to the end of the current sentence instead of cutting mid-sentence.
- Live mode must begin from the current caret position instead of always restarting from the start of the text.
- Live mode chunk size is a positive word count and defaults to `10`.
- Live mode uses the same selected ready model, speaker, and speed settings as normal synthesis.
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
- live-mode chunk generation fails after earlier chunks have already started playback
- Pocket TTS bundled reference clip missing from an installed model directory
- `.wav` file write failure
