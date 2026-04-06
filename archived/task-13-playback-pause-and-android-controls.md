# Playback Pause And Android Task Controls

## Goal

Make generated-speech playback pause and resume from the current position instead of resetting to the beginning, and ensure Android task actions remain usable during playback.

## Current Status

Completed. Generated-audio task rows now use play/pause semantics, resuming the same audio preserves the paused position on desktop and Android, and task cancel or remove actions pause playback before confirmation.

## Scope

- Change generated-audio task playback from play/stop to play/pause/resume.
- Preserve the paused playback position when resuming the same generated audio.
- Pause current playback before showing cancel or remove confirmation for task-row actions.
- Add confirmation before removing generated audio from a completed task.
- Keep desktop and Android behavior aligned for this Basic functionality flow.

## Outcome

1. Shared generated-audio controls now show pause while playing and resume from the paused position.
2. Android task-row cancel and remove flows now pause playback before confirmation instead of leaving playback running.
3. Generated-audio removal now asks for confirmation before deleting the local WAV file.
4. Playback domain docs and shared UI tests were updated to cover the new behavior.
