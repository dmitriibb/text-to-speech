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

- Scenario: Model switching or speech generation takes long enough to outlive the current screen frame or app foreground state.
  Expected handling: the work runs in the Android background task service, the UI stays interactive, and the task remains visible in the task list.

- Scenario: The user cancels a queued long-running task.
  Expected handling: the task is removed immediately, disappears from the task list, and produces no result.

- Scenario: The user cancels a running synthesis or model-load task.
  Expected handling: the task transitions to `cancelling`, the UI stays interactive, and any late result is discarded instead of replacing the current output.

- Scenario: Android repair is offered for a broken model but the model is still unusable after repair.
  Expected handling: the app keeps the model non-ready and surfaces the real failure instead of pretending repair worked.

- Scenario: Linux desktop has no `ffplay` or `aplay` available.
  Expected handling: playback fails with an actionable dependency message.

- Scenario: Share or export fails after a successful synthesis.
  Expected handling: the generated `.wav` stays available and only the output action fails.

- Scenario: A model is approved for local validation but redistribution evidence is still missing.
  Expected handling: development may continue, but shipping decisions remain blocked.