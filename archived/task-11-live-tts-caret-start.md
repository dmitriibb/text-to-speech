# Live TTS Caret Start

## Goal

Make live TTS start from the current text caret position instead of always starting from the beginning of the input.

## Current Status

Implemented. Live TTS now starts from the current text caret position, keeps chunk highlighting aligned to the full input, and shows a clear error if playback is started from the very end of the text.

## Scope

1. Capture the current caret position from the shared text editor.
2. Start live chunk splitting from that offset.
3. Keep chunk highlighting aligned to the original full text.
4. Validate the new behavior with targeted tests.
