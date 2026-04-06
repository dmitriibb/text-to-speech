# Playback Lifecycle

## States

- `stopped`
- `playing`
- `paused`

## Transitions

- `stopped -> playing`
  - when playback starts successfully for an existing `.wav`
- `stopped -> stopped`
  - when the user seeks or resets the currently loaded audio without resuming playback
- `playing -> paused`
  - when the user presses pause or the app pauses playback before a destructive task action
- `playing -> stopped`
  - when playback finishes, another audio replaces the active one, the app resets playback, or playback fails
- `paused -> playing`
  - when playback resumes from the paused position
- `paused -> stopped`
  - when playback is cancelled or reset
- `playing|paused -> playing`
  - when the user seeks within the same loaded audio and playback continues

## Notes

- Exactly one generated audio may be active at a time across the app.
- The shared generated-audio player uses play/pause semantics; full stop is reserved for reset, removal, replacement, shutdown, or failure.
- Pause, seek, and destructive task actions must take effect during active playback rather than waiting for the clip to finish.
- Both desktop and Android now use in-app player state with seekable position updates.
