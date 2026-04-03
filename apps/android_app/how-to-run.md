# How to Run the Android App

Short setup guide for Ubuntu, Windows, and macOS.

## 1. Install Flutter

Install Flutter stable for your OS, add it to `PATH`, then run:

```bash
flutter doctor
```

Official guide: https://docs.flutter.dev/get-started/install

## 2. Install Android tooling

Install Android Studio, then use `SDK Manager` to install at least:

- Android SDK Platform
- Android SDK Platform-Tools
- Android SDK Command-line Tools (latest)
- Android Emulator
- one `Google APIs x86_64` system image

Then accept licenses:

```bash
flutter doctor --android-licenses
```

## 3. Extra host packages for Ubuntu

### Required for Android Studio and SDK tools

```bash
sudo apt-get update
sudo apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386
```

### Recommended for emulator acceleration

```bash
sudo apt-get install -y cpu-checker qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo usermod -aG kvm,libvirt $LOGNAME
```

Log out and back in after changing groups.

## 4. Create an emulator

Minimal recommended AVD for this repo:

- Device: `Pixel 6a`
- Image: `Google APIs`
- ABI: `x86_64`
- API: one current installed Android API level

Create it in Android Studio `Device Manager` once.

## 5. Start the emulator without Android Studio

After the SDK and AVD already exist, you do not need to keep Android Studio open.

List available emulators:

```bash
flutter emulators
```

Start one through Flutter:

```bash
flutter emulators --launch <emulator-id>
```

Or start it directly from the Android SDK:

```bash
$ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_6a
```

This usually saves a few GB of RAM compared with leaving Android Studio open.

## 6. Verify the device is visible

```bash
flutter devices
adb devices
```

You should see either your emulator or your phone.

## 7. Run the app

From this directory:

```bash
flutter pub get
flutter run
```

Or target a specific Android device:

```bash
flutter run -d <device-id>
```

## 8. Platform notes

### Ubuntu

- Use the package steps above
- Emulator acceleration depends on KVM

### Windows

- Install Android Studio and the SDK from Android Studio
- Use either a phone or an x86_64 emulator through Device Manager

### macOS

- Install Android Studio and the SDK from Android Studio
- Use either a phone or an x86_64 or arm64 emulator that matches the machine

## Troubleshooting

- `cmdline-tools component is missing`: install `Android SDK Command-line Tools (latest)` in SDK Manager
- `Android license status unknown`: run `flutter doctor --android-licenses`
- Emulator is slow on Ubuntu: verify KVM and group membership, then log out and back in
- If a phone cancels install, retry with the emulator first to separate device policy issues from app issues