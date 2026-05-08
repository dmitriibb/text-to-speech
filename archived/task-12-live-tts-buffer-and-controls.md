# Live TTS Buffer And Controls

## Goal

Improve live TTS with separate play or pause and stop controls, and keep the generated ready-chunk buffer between 2 and 4 chunks while using up to 2 concurrent generation workers.

## Current Status

Implemented. Live mode now has separate play or pause and stop controls, stop clears temporary generated chunk buffers, and shared live scheduling keeps the ready chunk buffer between 2 and 4 while using up to two concurrent generation workers.

## Scope

1. Add play or pause plus stop controls to the live editor.
2. Make stop cancel further generation and clear generated chunk buffers.
3. Keep 2 to 4 ready chunks buffered ahead of playback.
4. Start 2 concurrent generations when the ready buffer drops to 2 or less.
5. Validate the updated scheduling and control behavior with targeted tests.
