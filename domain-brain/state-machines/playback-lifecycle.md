# Playback Lifecycle

## States

- `stopped`
- `playing`
- `paused`

## Transitions

- `stopped -> playing`
  - when playback starts successfully for an existing `.wav`
- `playing -> paused`
  - when the platform player exposes a paused-ready state
- `playing -> stopped`
  - when playback finishes, is stopped by the user, or fails
- `paused -> playing`
  - when playback resumes
- `paused -> stopped`
  - when playback is cancelled or reset

## Notes

- Desktop currently behaves mostly as `stopped <-> playing`.
- Android playback can surface a pause-like ready state through `just_audio`.