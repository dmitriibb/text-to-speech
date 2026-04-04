# Audio Playback Controls And Shutdown

## Goal

Fix audio playback so the app behaves like a normal player, never plays more than one audio at a time, and stops playback plus long-running work when the app closes.

## Current Status

- Implementation complete in code
- Shared task playback UI now shows play/stop plus a seekable progress slider
- Desktop playback now serializes process control so only one audio can play at a time
- App shutdown now stops playback and cancels active background work
- Verified with `flutter analyze` in `apps/desktop_app` and `apps/android_app`

## Scope

- Add play/stop plus a seekable progress control for generated audio playback
- Enforce a single active audio playback session across the app
- Stop playback and cancel background work during app shutdown
- Keep desktop and Android playback UX aligned for this Basic feature

## Next Steps

- Run manual desktop playback checks for rapid repeated play clicks, seeking, and app-close cleanup
- Run manual Android playback checks for seek behavior on device
