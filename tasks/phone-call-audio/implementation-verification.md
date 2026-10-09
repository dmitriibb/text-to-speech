# Russian-dialog implementation verification

Completed 2026-10-09. All engineering deliverables are ready for user testing.
VoxCPM2 remains the provisional engine until listening acceptance. AMD acceleration
and task 19's broader Home/German integration are separate work.

## Automated verification

| Suite | Result |
| --- | --- |
| tts_core | 59 tests passed |
| shared_ui | 14 tests passed, including 320 px layout and turn edit/apply |
| desktop_app | 21 tests passed; opt-in real test skipped in ordinary runs |
| android_app | 5 tests passed |
| VoxCPM2 backend | 13 tests passed; existing Starlette deprecation warning |
| Russian evaluator | 3 tests passed |
| Real HTTP application adapter harness | 1 test passed separately |
| Analysis | Both shared packages and both apps: no issues |

Shared regression coverage includes actor isolation, import diagnostics, late
response rejection, cancel/remove/edit/retry, timing edits during inference,
three-actor project reload, changed/missing/corrupt assets, mixed PCM rates/channels,
anti-alias rejection, exact pauses/headroom and cancelled render publication.
The streaming renderer processed a synthetic ten-minute/600-turn conversation
with exact WAV size and manifest frame/turn counts. This proves rendering length,
not long-script voice stability. New-script 2–5 minute and roughly ten-minute
listening runs remain user acceptance cases.

## Real CPU and Audacity evidence

Pinned model: `openbmb/VoxCPM2`, revision
`32279effe8c19989596f05d353d1447f51d9e915`, `voxcpm==2.0.3`.
Earlier evaluation generated 20 two-actor and six three-actor turns; see
[evaluation](evaluation.md) for timings/reference paths.

The opt-in desktop harness used actual HTTP inference, three persistent candidate
reference actors, retry of one turn without changing the other clips, save/reload
and the shared renderer. It passed in approximately 2 minutes 23 seconds. The
15.17-second master is 48 kHz mono PCM16. Local ignored outputs:

- `artifacts/russian-dialogue/app-smoke-1791546225427/technical-acceptance.json`
- `artifacts/russian-dialogue/app-smoke-1791546225427/project.json`
- `artifacts/russian-dialogue/app-smoke-1791546225427/renders/conversation-1791546368658348-10.wav`
- `artifacts/russian-dialogue/app-smoke-1791546225427/conversation-phone.wav`
- `artifacts/russian-dialogue/app-smoke-1791546225427/conversation-phone.aup3`
- `artifacts/russian-dialogue/app-smoke-1791546225427/conversation-phone.json`

Audacity 3.7.7 applied the saved Filter Curve EQ/Compressor/Normalize macro,
exported 16 kHz mono PCM16, saved/reopened the AUP3 and reexported. Sample difference
was exactly zero and the clean master hash was unchanged. This technically
validates the preset and preserved source; intelligibility/distinct voices still
require listening. No added noise/codec/distortion was enabled.

## Builds and repeatable checks

Android debug build succeeded with isolated Adoptium Java 17.0.20.1. Its APK is
`apps/android_app/build/app/outputs/apk/debug/app-debug.apk`. Host Java 25 fails
this Gradle setup; see the Android run instructions. The isolated JDK remains in
ignored `artifacts/russian-dialogue/build-runtime/jdk/`. Existing Kotlin/Gradle
migration notices do not prevent this build.

Windows executable build is blocked by the host's missing Visual Studio C++
toolchain. Local ignored plugin junctions bypassed the host symlink limitation
without changing system settings. Normal Windows setup still requires the Flutter
Windows toolchain and plugin symlink support. Desktop Dart analysis and tests
passed; native Windows playback/export and physical Android sharing were not
executed in a running app.

Run `flutter test --no-pub` in each app/shared package, `dart analyze` in those four
directories, `.venv/Scripts/python.exe -m pytest tests -q` from `apps/voxcpm2_be`,
and `python -m unittest discover -s tests -p test_russian_dialogue_evaluation.py`
from the repository root. For the real harness, start the pinned backend, set
`TTS_REAL_BACKEND` to its endpoint, then run
`flutter test --no-pub test/russian_dialogue_real_test.dart` from desktop_app.
It reuses local three-actor evaluation references and writes a new artifact folder.

## Basic functionality parity

- Identical shared implementation on desktop and Android: independent actors,
  transcript editing/overrides/exclusion, selective sequential generation/retry,
  safe cancellation, versioned save/reload, timing, streamed master rendering,
  validation/manifests and shared preview/export controls.
- Platform adapters: native local synthesis/playback/storage, desktop save-file
  and Android system share. Both deliver the same finished WAV; native behavior
  still needs the user's device checks.
- No Basic feature remains unwired on either app. VoxCPM2 Python/reference picker
  is desktop Extended; Android uses installed local models. No new Russian Android
  voice model was bundled or approved by this work.

Start testing with the [workflow guide](../../docs/russian-phone-call-workflow.md).
D2/M1 voice selection and D10/M5 listening/device acceptance remain visibly open.
