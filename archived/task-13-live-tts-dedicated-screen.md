# Live TTS Dedicated Screen

## Goal

Move live TTS off the Home screen into its own navigation destination, while restoring Home to the normal text-generation flow.

## Current Status

Implemented in both apps. Home is back to normal text input plus settings and task list, and live TTS now lives on its own screen with top controls and a full-height editor.

## Scope

1. Add a `Live TTS` navigation destination in desktop and Android.
2. Restore the Home screen to standard text generation UI only.
3. Add a dedicated live screen with chunk size, play or pause, stop, and a large internally scrollable text editor.
4. Stop live playback and background generation when navigating away from the dedicated live screen.
