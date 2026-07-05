# Dialog Mode (Basic)

## Goal

Add a Dialog navigation mode where pasted speaker-prefixed lines can be parsed, assigned per-speaker voices, generated line by line, and played either as a full sequence or as individual lines.

## Current Status

Completed. Dialog mode is implemented for desktop and Android with shared parsing, shared UI, per-speaker model and voice assignments, per-line generation, full sequence play/pause/stop, individual line playback, line removal, and text clearing.

## Scope

- Add Dialog to desktop and Android navigation.
- Parse clipboard lines in the form `Speaker: text`.
- Show one speaker settings row per parsed speaker with model and speaker selection.
- Generate audio for each non-empty dialog line.
- Play, pause, stop, and restart the full generated dialog sequence.
- Let each line be played individually, removed, or cleared while keeping its speaker label visible.
- Keep shared parsing and UI in shared packages, with platform-specific clipboard, output path, and audio wiring in app state.

## Next Steps

None for this task.
