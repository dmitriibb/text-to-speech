# Windows Desktop Playback Control

## Goal

Fix the Windows desktop playback bug where pressing play again or moving the progress slider starts overlapping audio instead of controlling the currently active clip.

## Current Status

Completed. The desktop app now uses an in-process Windows MCI playback controller instead of the spawned PowerShell `Media.SoundPlayer` fallback. Repeated play, pause, stop, and seek actions now target the same loaded clip, so Windows no longer layers concurrent audio when the user replays or drags the progress slider.

## Blockers

- None.

## Next Steps

1. Validate the behavior manually on a Windows desktop run against a real generated WAV clip.
