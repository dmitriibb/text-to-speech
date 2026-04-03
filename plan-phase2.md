# Phase 2 Plan: Android MVP

Updated: 2026-04-03

## 1. Goal

Phase 2 builds the **second user-facing application** in this monorepo:

- a **Flutter Android app**
- that generates **English speech locally on-device**
- using the same **offline sherpa-onnx model/runtime direction** as the desktop app
- with **no cloud TTS dependency**

Decision for the current task:

- Ubuntu desktop validation is **good enough for now**.
- We do **not** block Phase 2 planning on Windows desktop validation.

Current host context:

- development machine is an **Ubuntu laptop**
- Android Studio and Android SDK are **not installed yet**
- `apps/android_app` is still only a placeholder

## 2. Starting Point

What is already true in the repo:

- Phase 0 validated the local `sherpa-onnx` runtime path with benchmark texts and generated `.wav` files
- the desktop app already proves local synthesis via the `sherpa_onnx` Flutter plugin
- the approved model catalog already exists in machine-readable JSON
- the current Android folder does not yet contain a Flutter app

Important implementation reality:

- most reusable logic is still inside `apps/desktop_app`
- the current desktop `ModelService` uses desktop-only assumptions:
  - XDG and Windows paths
  - environment variables
  - `Process.run('tar', ...)` for model extraction
- the current desktop `AudioService` uses process-based playback and is not usable on Android

Important product/legal reality:

- the current validated development voice is still acceptable for local development
- redistribution-safe default voice selection is still **not finalized**
- Android development may continue against a development model, but shipping remains blocked until a release-safe voice is approved

## 3. Definition Of Done

Phase 2 is done when all of the following are true:

- `apps/android_app` contains a runnable Flutter Android app
- the app builds a debug APK on Ubuntu
- the app runs on at least one Android target:
  - physical device preferred
  - emulator acceptable if device access is not available
- the app can install or detect one approved English model in Android-safe storage
- the app can generate understandable English speech locally with no network requirement after model install
- the app can play generated speech inside the app
- the app can persist generated `.wav` output and expose a share path
- the app supports speed control
- the app handles empty input, missing model, download failure, synthesis failure, and playback/share failure cleanly
- one Android manual smoke-test pass is recorded on a reference target

## 4. Scope

### In scope

- Android Flutter app shell in `apps/android_app`
- extraction of only the **stable cross-platform logic** needed to support both desktop and Android
- Android-safe local model storage
- one English voice path for development
- text input, voice selection, speed control, generate action
- local playback inside the app
- `.wav` persistence plus Android share flow
- basic settings/status UI for model readiness
- offline synthesis after model installation
- basic Android smoke testing

### Out of scope

- Google Play publication work
- Android background TTS service integration with the system TTS engine
- voice cloning
- tone/style control
- multiple advanced model families
- model fine-tuning
- desktop-quality upgrade work
- large shared UI abstraction work unless duplication becomes real

## 5. Main Technical Decisions

### Android app framework

Use **Flutter** in `apps/android_app`.

Reason:

- it matches the monorepo direction
- it lets us reuse state, domain, and runtime code where that is actually stable
- it keeps Android aligned with the existing desktop implementation

### Runtime choice

Use the **`sherpa_onnx` Flutter plugin** on Android, just as on desktop.

Reason:

- the desktop app already proves the Flutter runtime path
- the broader project plan already chose `sherpa-onnx` as the offline engine
- Phase 2 should validate the same runtime family on the second platform, not introduce a new inference stack

### Reuse strategy

Do **not** copy the desktop app wholesale.

Do **not** over-abstract the whole app before Android exists.

Extract only the parts that are already clearly cross-platform into `packages/tts_core` as Phase 2 begins:

- `VoiceModel` and installed-model metadata types
- catalog parsing and model metadata validation
- model file validation helpers
- synthesis request/result models
- a cross-platform `TtsService` wrapper around `sherpa_onnx` if it stays platform-neutral
- shared error types and input validation rules

Keep these Android-specific in `apps/android_app`:

- storage paths
- download orchestration if it depends on Android app lifecycle
- audio playback implementation
- share/export flow
- permissions and target-device handling
- Android UI screens and widgets

### Model install strategy

Android cannot rely on desktop paths or shell tools.

Therefore:

- store models in an app-private directory from `path_provider`
- do not depend on workspace `models/` lookup on Android
- do not depend on environment variables for the normal Android path
- replace shell-based archive extraction with a **pure Dart** implementation

Recommended implementation direction:

- use the `archive` package for `.tar.bz2` extraction so the same extraction path can work on Android and desktop

This is the root-cause fix needed for mobile support.

### Playback and export strategy

The desktop process-based audio service cannot be reused.

Recommended Android MVP path:

- play local `.wav` files through a Flutter audio playback package such as `just_audio`
- write generated `.wav` files into app-private storage first
- expose a **Share** action through `share_plus`
- treat direct user-selected filesystem export as a later enhancement, not a Phase 2 blocker

This still satisfies the main Phase 2 promise of save/share without forcing early Android storage-complexity work.

### Device strategy

For this Ubuntu laptop, prefer a **physical Android device first**.

Reason:

- it avoids emulator setup and performance overhead if a phone is available
- it gives a more realistic CPU and storage signal for local TTS
- it reduces setup friction on the current machine

Use the Android emulator as a fallback or secondary validation path.

### Permission strategy

For the MVP, keep permissions minimal:

- Internet access is required only for model download
- no microphone permission is needed
- no broad storage permission is needed if files stay app-private and sharing uses Android sharesheets

## 6. Ubuntu Android Development Prerequisites

This section lists the setup needed to begin Android work on the current Ubuntu laptop.

### Required baseline setup

| Item | Why we need it | How to install | How to check it |
|---|---|---|---|
| Flutter SDK | Build and run the Android Flutter app | If Flutter is already installed for desktop, reuse it. Otherwise install Flutter from the official stable SDK and ensure `flutter` is on `PATH`. | Run `flutter --version` and `flutter doctor` |
| Android Studio | Manage the Android SDK, Gradle integration, emulator, and Android tooling that Flutter expects | Download the Linux `.tar.gz` from Android Studio, extract it to a user-writable path such as `~/android-studio`, then run `~/android-studio/bin/studio` and complete the setup wizard | `~/android-studio/bin/studio --version` launches successfully, and `flutter doctor` shows Android Studio detected |
| Android SDK packages | Build, deploy, and debug Android apps | In Android Studio SDK Manager, install: Android SDK Platform API 36, Android SDK Build-Tools, Android SDK Command-line Tools, Android SDK Platform-Tools, Android Emulator, CMake, and NDK (Side by side) | Run `flutter doctor -v`, `flutter devices`, and `adb --version` |
| Android SDK licenses | Flutter refuses Android builds until SDK licenses are accepted | Run `flutter doctor --android-licenses` and accept all licenses | Output includes `All SDK package licenses accepted.` |

### Sudo-required packages on Ubuntu

| Item | Why we need it | How to install | How to check it |
|---|---|---|---|
| 32-bit compatibility libraries for Android Studio | Android Studio on 64-bit Ubuntu still requires these compatibility libraries | `sudo apt-get update && sudo apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386` | Android Studio starts without missing-library errors |

Notes:

- A separate system JDK is **not required by default** if Android Studio's bundled runtime is used.
- Android Studio itself does **not** require `sudo` if it is installed under your home directory.

### If using a physical Android device over USB

| Item | Why we need it | How to install | How to check it |
|---|---|---|---|
| `android-sdk-platform-tools-common` | Installs Ubuntu `udev` rules so `adb` can see many Android devices | `sudo apt-get install -y android-sdk-platform-tools-common` | Connect the phone with USB debugging enabled, then run `adb devices` |
| `plugdev` group membership | Required on Ubuntu for user access to ADB devices | `sudo usermod -aG plugdev $LOGNAME` and then log out and back in | Run `id` and confirm `plugdev` is listed |

Device-side checks:

- enable Developer options
- enable USB debugging
- accept the RSA trust prompt on the phone
- run `adb devices` and confirm the phone appears as `device`

### If using the Android emulator

| Item | Why we need it | How to install | How to check it |
|---|---|---|---|
| `cpu-checker` | Quick check that virtualization support is available | `sudo apt-get install -y cpu-checker` | Run `kvm-ok` |
| KVM packages | Hardware acceleration for the Android Emulator on Linux | `sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils` | Run `kvm-ok` and `${ANDROID_SDK_ROOT}/emulator/emulator -accel-check` |

Expected healthy output:

- `kvm-ok` should report `KVM acceleration can be used`
- `emulator -accel-check` should report that KVM is installed and usable

If a physical device is available, this emulator setup can be deferred.

## 7. Planned App Architecture

### UI layer

Lives in `apps/android_app/lib/`.

Planned screens/components:

- main TTS screen
- text input panel
- voice and speed controls
- model status/install card
- generate action bar
- playback panel
- share/export action
- basic settings/help section if needed

### State layer

Use the same simple direction as desktop first:

- `ChangeNotifier`
- `Provider`

Reason:

- it keeps the Android app aligned with current repo conventions
- it avoids introducing a second state-management pattern during the platform expansion phase

### Shared core layer

Move stable reusable code into `packages/tts_core` only when there is a clear Android consumer.

Planned responsibilities:

- catalog parsing
- model metadata types
- synthesis request/result types
- reusable model-file validation
- `sherpa_onnx` wrapper if it remains cross-platform

### Android service layer

Keep Android-specific services in the app initially:

- `AndroidModelStorageService`
- `AndroidDownloadService`
- `AndroidAudioService`
- `AndroidExportService`

### Runtime path

1. App loads the approved model catalog.
2. App checks app-private model storage.
3. If model is missing, app offers download.
4. App downloads the model archive.
5. App extracts the archive using a pure Dart path.
6. App loads the model through `sherpa_onnx`.
7. App generates audio into an app-private `.wav` file.
8. User plays or shares the result.

## 8. Step Order

### Step 1: Install the Android toolchain on Ubuntu

- install the Ubuntu prerequisites
- install Android Studio
- install the SDK packages
- accept Android licenses
- choose the first Android test target:
  - physical device preferred
  - emulator fallback

Expected result:

- `flutter doctor` is clean enough to build Android apps
- `flutter devices` shows at least one Android target

### Step 2: Scaffold `apps/android_app`

- create the Flutter Android app shell
- set package identifiers and app name
- confirm `flutter run` works with the default counter app on an Android target

Expected result:

- the repo has a runnable Android Flutter project before TTS integration starts

### Step 3: Extract the minimum stable shared core

- move reusable model metadata and catalog parsing out of `apps/desktop_app`
- add shared model-file validation helpers
- move or recreate the platform-neutral TTS wrapper in `packages/tts_core`
- keep desktop-only audio and path logic out of the shared package

Expected result:

- Android can reuse proven logic without inheriting desktop-only assumptions

### Step 4: Replace shell-based archive extraction

- remove dependence on `Process.run('tar', ...)` for the shared model-install path
- implement archive extraction in Dart
- validate the new extraction flow on desktop before relying on it on Android

Expected result:

- model install logic is portable across desktop and Android

### Step 5: Implement Android model storage and install flow

- select the app-private models directory with `path_provider`
- detect installed models
- download the development model
- persist and validate extracted files
- surface download progress and install errors in UI

Expected result:

- the Android app can become synthesis-ready by itself

### Step 6: Implement Android synthesis flow

- load the selected model
- generate a local `.wav`
- wire the generate action into Android app state
- handle empty input and runtime failures

Expected result:

- typed English text produces local speech on Android

### Step 7: Implement Android playback and share/export

- play the generated `.wav` in-app
- stop playback cleanly
- persist the output file in app storage
- share the generated file through the Android sharesheet

Expected result:

- the Android app is useful end-to-end for the core TTS workflow

### Step 8: Add polish and failure handling

- disable duplicate generate actions during synthesis
- keep the last generated result available when possible
- improve error messages for missing model, download failures, and playback issues
- confirm behavior after app restart

Expected result:

- the app survives repeated manual testing without basic workflow failures

### Step 9: Run Android smoke tests

- launch the app on the reference target
- install the model
- generate short text
- generate medium text
- change speed and generate again
- play the result
- share the `.wav`
- restart the app and confirm the model is still detected
- disable network and confirm synthesis still works after install

Expected result:

- the Android MVP promise is demonstrated on a real target

## 9. Testing Plan

### Automated tests

- unit tests for shared catalog parsing
- unit tests for model-file validation
- unit tests for app-state transitions around synthesis and model install
- widget tests for basic Android UI flows where practical

### Manual smoke tests

Run the following on the reference Android target:

1. Launch the app with no model installed
2. Install the model from the app
3. Generate speech from a short sentence
4. Generate speech from a medium paragraph
5. Change speed and generate again
6. Play the generated audio
7. Share the generated `.wav`
8. Restart the app and confirm the model is still detected
9. Turn off network access and confirm synthesis still works

### Performance checks

Record at least these values on one reference Android target:

- approximate model download size
- time to first successful synthesis after install
- synthesis time for short and medium inputs
- rough app storage used by model plus one exported `.wav`

Unknown:

- final acceptable latency threshold on the reference Android device

Needed to decide:

- choose one reference Android device or emulator target
- record an acceptable short-text and medium-text latency target for that device

## 10. Deliverables

Phase 2 should produce:

- a runnable Flutter Android app in `apps/android_app`
- a shared `packages/tts_core` package only for logic that is actually reused
- Android model install and detection flow
- Android local synthesis path using `sherpa_onnx`
- Android playback and share flow
- Phase 2 setup/run notes for Ubuntu Android development
- one recorded Android smoke-test pass

## 11. Known And Accepted Limitations

- English only
- one development voice path to start
- model is downloaded after install, not bundled into the APK initially
- share flow is preferred over arbitrary filesystem export in the MVP
- no Android system-level TTS service integration
- no voice cloning
- no background batch synthesis
- CPU-only inference assumptions remain acceptable for MVP

## 12. Main Risks

### Risk: `sherpa_onnx` Android runtime integration differs from desktop expectations

Mitigation:

- prove one hardcoded synthesis path on Android before building polished UI

### Risk: current model install code is not portable

Mitigation:

- replace shell-based extraction before deeper Android integration

### Risk: emulator setup is slow or heavy on the Ubuntu laptop

Mitigation:

- prefer a physical device first
- treat emulator setup as optional if a phone is available

### Risk: Android storage/export UX becomes a time sink

Mitigation:

- keep files app-private first
- use Android sharesheet early
- defer custom export UX

### Risk: release-safe voice selection is still unresolved

Mitigation:

- keep development moving with the current validated model
- do not treat shipping approval as solved until licensing evidence is captured

## 13. Explicit Unknowns

Unknown:

- exact Android minimum SDK after plugin and Gradle sync
- reference Android device for acceptance
- final release-safe default English voice
- final APK size target
- final export UX beyond the share flow

Needed to decide:

- one reference Android device or emulator image
- whether physical-device-first development is enough for Phase 2 acceptance
- whether direct save-to-Downloads is needed in Phase 2 or can wait
- acceptable synthesis latency on the reference device

## 14. Recommended First Implementation Slice

The first Phase 2 implementation slice should be:

1. Install the Android toolchain and detect one Android target
2. Scaffold `apps/android_app`
3. Add the minimum dependencies needed for Android TTS work
4. Prove one model load and one hardcoded synthesis call on Android
5. Play the generated result in-app

Reason:

- this is the shortest path from the already proven desktop runtime to the first real Android milestone
- it exposes plugin, ABI, storage, and playback issues before the rest of the app is built

## 15. Source Notes Used For This Plan

Current repo files:

- `plan-main.md`
- `plan-phase1.md`
- `docs/architecture.md`
- `docs/how-to-run.md`
- `docs/licensing.md`
- `apps/android_app/README.md`
- `apps/desktop_app/lib/state/app_state.dart`
- `apps/desktop_app/lib/services/tts_service.dart`
- `apps/desktop_app/lib/services/model_service.dart`
- `apps/desktop_app/lib/services/audio_service.dart`

Official sources checked on 2026-04-03:

- Flutter Android setup: https://docs.flutter.dev/platform-integration/android/setup
- Android Studio Linux install: https://developer.android.com/studio/install
- Android emulator acceleration: https://developer.android.com/studio/run/emulator-acceleration
- Android physical device setup: https://developer.android.com/studio/run/device
- sherpa-onnx Flutter Android TTS APK examples: https://k2-fsa.github.io/sherpa/onnx/flutter/tts-android-cn.html