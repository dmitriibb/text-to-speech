# android_app

Flutter Android MVP for local offline text-to-speech.

## Current scope

- loads the approved model catalog from app assets
- installs models into app-private storage
- extracts `.tar.bz2` archives in Dart via the shared `tts_core` package
- generates speech locally with `sherpa_onnx`
- plays generated audio in-app with `just_audio`
- shares generated `.wav` files with the Android sharesheet

## Full Setup Guide

For full Android setup and run instructions, see [how-to-run.md](how-to-run.md).

## Run

From `apps/android_app`:

```bash
flutter pub get
flutter run
```

The Dart code, Flutter analysis, and Flutter tests pass in this repo.

You still need a configured Android SDK plus either a phone or an emulator before `flutter run` can launch the app.
