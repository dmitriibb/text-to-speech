# android_app

Flutter Android MVP for local offline text-to-speech.

## Current scope

- loads the approved model catalog from app assets
- installs models into app-private storage
- extracts `.tar.bz2` archives in Dart via the shared `tts_core` package
- generates speech locally with `sherpa_onnx`
- plays generated audio in-app with `just_audio`
- shares generated `.wav` files with the Android sharesheet

## Run

From `apps/android_app`:

```bash
flutter pub get
flutter run
```

## Current host limitation

The Dart code, Flutter analysis, and Flutter tests pass in this repo, but a real Android APK build is still blocked on this Ubuntu machine until Android Studio and the Android SDK are installed and accepted.
