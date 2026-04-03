# How to Run the Desktop App

Short setup guide for Ubuntu, Windows, and macOS.

## 1. Install Flutter

Install Flutter stable for your OS, add it to `PATH`, then run `flutter doctor`.

Official guide: https://docs.flutter.dev/get-started/install

Enable the desktop target for your platform:

```bash
flutter config --enable-linux-desktop
```

```powershell
flutter config --enable-windows-desktop
```

```bash
flutter config --enable-macos-desktop
```

## 2. Install platform prerequisites

### Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev \
  lld ffmpeg zenity
```

### Windows

- Install Visual Studio 2022 with `Desktop development with C++`
- Follow any remaining `flutter doctor` prompts

### macOS

- Install Xcode
- Install CocoaPods: `sudo gem install cocoapods`
- Follow any remaining `flutter doctor` prompts

## 3. Get the app running

From this directory:

```bash
flutter pub get
flutter run -d linux
```

```powershell
flutter pub get
flutter run -d windows
```

```bash
flutter pub get
flutter run -d macos
```

## 4. Make sure a model is available

The desktop app can:

- download a model in-app, or
- auto-detect the repo model in `../../models/`, or
- use `TTS_MODELS_PATH`

Custom model path example:

```bash
TTS_MODELS_PATH=/path/to/models flutter run -d linux
```

## 5. Build a release binary

```bash
flutter build linux
```

```powershell
flutter build windows
```

```bash
flutter build macos
```

## Troubleshooting

- Ubuntu linker error: install `lld`
- Ubuntu playback issue: install `ffmpeg`
- Ubuntu save dialog missing: install `zenity`
- macOS support is expected to work through Flutter desktop support, but it is less validated than Linux