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
  - when the platform player exposes a paused-ready state
- `playing -> stopped`
  - when playback finishes, another audio replaces the active one, the user stops playback, or playback fails
- `paused -> playing`
  - when playback resumes
- `paused -> stopped`
  - when playback is cancelled or reset
- `playing|paused -> playing`
  - when the user seeks within the same loaded audio and playback continues

## Notes

- Exactly one generated audio may be active at a time across the app.
- Both desktop and Android now use in-app player state with seekable position updates.
