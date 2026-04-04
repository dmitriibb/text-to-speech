# Desktop App

Local text-to-speech desktop application for Ubuntu and Windows.

## Status

Phase 1 MVP - functional on Linux.

## Features

- Local TTS synthesis using sherpa-onnx (no cloud API)
- Text input with multi-line support
- Voice selection from approved model catalog
- Speed control (0.25x to 3.0x)
- Audio playback
- WAV file export
- Model download from within the app
- Offline operation after model install

## Full Setup Guide

For full desktop setup and run instructions, see [how-to-run.md](how-to-run.md).

## Prerequisites (summary)

- Flutter SDK (stable channel, desktop enabled)
- Linux: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, libgstreamer1.0-dev
- Audio playback: ffmpeg (for ffplay) or alsa-utils (for aplay)
- Save dialog: zenity (usually pre-installed on GNOME desktops)

## Development

```bash
# From this directory:
flutter pub get
flutter run -d linux

# Or build a release:
flutter build linux
```

The built app is at `build/linux/x64/release/bundle/desktop_app`.

## Model Setup

The app stores and scans models in one app-managed location:

- Linux: `~/.local/share/text-to-speech/models/`
- Windows: `%APPDATA%/text-to-speech/models/`

Models can also be downloaded from within the app when no model is installed.

## Architecture

```
lib/
  main.dart              Entry point
  app.dart               MaterialApp setup
  models/
    voice_model.dart     Model catalog data types
  services/
    tts_service.dart     sherpa-onnx TTS wrapper
    model_service.dart   Model detection, catalog, download
    audio_service.dart   Process-based audio playback
  state/
    app_state.dart       ChangeNotifier app state
  screens/
    home_screen.dart     Main screen layout
  widgets/
    text_input_panel.dart
    settings_panel.dart
    playback_panel.dart
    model_status_banner.dart
```
