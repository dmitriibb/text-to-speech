# Android Audio Player Responsiveness

## Goal

Make Android generated-audio playback respond immediately to pause, seek, and cancel/remove actions while audio is playing.

## Current Status

Completed. Android playback commands now stay responsive while audio is playing because the service no longer blocks its control queue on the long-lived `just_audio` playback future.

## Scope

- Refactor Android audio command handling so play does not block later control actions.
- Preserve correct paused semantics when seeking while paused.
- Add Android-focused regression coverage for command ordering.
- Keep the existing shared task-row UI contract intact.

## Outcome

1. Android `AudioService` now loads media through a short-lived command queue and starts playback outside that blocking path.
2. Pause and seek commands now execute immediately during active playback instead of waiting for clip completion.
3. Seeking while paused now preserves the paused state instead of converting the player to stopped semantics.
4. Android audio-service tests now cover non-blocking play, immediate pause, and paused seek behavior.
