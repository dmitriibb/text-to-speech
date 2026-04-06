# Voice Settings Parity

## Goal

Bring the basic voice settings back into parity across desktop and Android by tightening the shared speech-speed range to `0.5x` through `2.0x` with a default of `1.0x`, and by showing the Kokoro speaker dropdown on Android just like desktop.

## Current Status

Complete.

## Scope

- Change the app-supported speech-speed range to `0.5x` through `2.0x`.
- Keep the default speech speed at `1.0x`.
- Add Android speaker selection support for multi-speaker models such as Kokoro.
- Move the shared voice/speaker/speed controls into `packages/shared_ui/` so desktop and Android use the same basic settings UI.

## Completed

1. Added shared speech-speed constants and clamping for the new `0.5x` to `2.0x` range.
2. Extracted the shared voice, speaker, and speed controls into `packages/shared_ui/`.
3. Wired Android app state to track the selected speaker and pass it into synthesis tasks.
4. Updated the local-synthesis docs and verified the change with tests and analyzers.
