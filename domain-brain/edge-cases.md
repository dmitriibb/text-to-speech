# Edge Cases

- Scenario: A model directory exists but `tokens.txt` or `data_dir` is missing.
  Expected handling: the model remains `incomplete`, not `ready`.

- Scenario: Download completes but extraction leaves the wrong directory shape.
  Expected handling: validation fails and the install surfaces a concrete error.

- Scenario: User tries to generate speech with no installed or selected model.
  Expected handling: generation is blocked and the app shows a clear error.

- Scenario: User submits empty or whitespace-only text.
  Expected handling: synthesis does not start and the app shows validation feedback.

- Scenario: Network is disabled after a model is already installed.
  Expected handling: synthesis still works because runtime files are local.

- Scenario: A new synthesis starts while audio is already playing.
  Expected handling: playback is stopped before generation continues.

- Scenario: Live mode chunking would end in the middle of a sentence.
  Expected handling: the chunk extends through the sentence terminator and the next chunk starts with the next sentence.

- Scenario: The user edits the input text, speaker, speed, or model while live playback is active.
  Expected handling: the live session stops, queued chunk generation is cancelled, and stale chunk highlighting is cleared.

- Scenario: The user starts live mode with the text caret at the very end of the input or after only trailing whitespace.
  Expected handling: live playback does not start and the app shows a clear message telling the user to place the caret before some text.

- Scenario: The user stops live mode while future chunks are already generated or still generating.
  Expected handling: active playback stops, background chunk work is cancelled, and temporary chunk `.wav` buffers are deleted.

- Scenario: The user opens Dialog mode before importing any transcript.
  Expected handling: the screen shows only the `Paste from buffer` action.

- Scenario: Dialog clipboard content contains blank lines or rows without a `Speaker: text` separator.
  Expected handling: invalid rows are skipped; if no valid rows remain, import fails with a clear message.

- Scenario: The user changes a Dialog speaker's model or voice after generating line audio.
  Expected handling: generated audio for that speaker's lines is invalidated so playback cannot use stale output with the wrong voice.

- Scenario: The user stops Dialog sequence playback and presses play again.
  Expected handling: playback restarts from the first generated non-empty line.

- Scenario: A stale playback `stopped` event arrives while Dialog mode is loading the next line.
  Expected handling: auto-advance ignores it until the newly selected line has actually entered `playing`, so lines are not skipped or repeated.

- Scenario: Dialog generation queues several lines within the same system clock tick.
  Expected handling: each line still receives a unique task ID and output `.wav` path so rows cannot point at another line's generated audio.

- Scenario: The user pauses live mode while background generation is still running.
  Expected handling: current playback pauses in place, already in-flight chunk generation may finish, and buffering stops growing once 4 ready chunks are waiting.

- Scenario: Model switching or speech generation takes long enough to outlive the current screen frame or app foreground state.
  Expected handling: the work runs in the Android background task service, the UI stays interactive, and the task remains visible in the task list.

- Scenario: The user cancels a queued long-running task.
  Expected handling: the task is removed immediately, disappears from the task list, and produces no result.

- Scenario: The user confirms Clear all while synthesis work is active.
  Expected handling: playback stops, managed work is cancelled and removed, every known generated `.wav` and persisted task record is deleted, and a late worker result deletes its output instead of restoring the task.

- Scenario: The user cancels a running synthesis or model-load task.
  Expected handling: the task transitions to `cancelling`, the UI stays interactive, and any late result is discarded instead of replacing the current output.

- Scenario: Android repair is offered for a broken model but the model is still unusable after repair.
  Expected handling: the app keeps the model non-ready and surfaces the real failure instead of pretending repair worked.

- Scenario: Linux desktop has no `ffplay` or `aplay` available.
  Expected handling: playback fails with an actionable dependency message.

- Scenario: The desktop user opens the Voice Lab sample picker and cancels file selection.
  Expected handling: the import dialog stays open, no error is shown, and no voice is created.

- Scenario: The desktop user selects a WAV sample for Voice Lab, but the file is removed before import completes.
  Expected handling: import is blocked and the UI shows a concrete file-not-found error.

- Scenario: The desktop user selects an MP3 sample for Voice Lab.
  Expected handling: the app detects the MP3 automatically, converts it to a stored WAV reference clip during import, and keeps the rest of the cloning flow unchanged.

- Scenario: The desktop user selects an MP3 sample for Voice Lab, but `ffmpeg` is unavailable or conversion fails.
  Expected handling: import is blocked and the UI shows a concrete conversion error instead of saving an unusable reference clip.

- Scenario: Share or export fails after a successful synthesis.
  Expected handling: the generated `.wav` stays available and only the output action fails.

- Scenario: A model is approved for local validation but redistribution evidence is still missing.
  Expected handling: development may continue, but shipping decisions remain blocked.
