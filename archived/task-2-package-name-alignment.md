# Package Name Alignment

## Goal

Rename application and artifact identifiers so they use the `com.dmbb.tts` prefix.

## Current Status

- Complete
- Android now uses `com.dmbb.tts.android` for both namespace and application ID
- Desktop Linux now uses `com.dmbb.tts.desktop` as the GTK application ID
- Desktop Windows runner metadata now uses the `com.dmbb.tts` company prefix
- No source or documentation references to the old identifiers remain outside generated build outputs

## Blockers / Unknowns

- macOS bundle identifier rename is not applicable in the current repo because there is no macOS target
- Linux desktop build was not rerun from the agent after a VS Code terminal UI error, so local native build verification may still be useful on this machine

## Outcome

- Updated Android Gradle config, Kotlin package path, Linux runner config, and Windows runner metadata together
- Verified `flutter analyze` for `apps/android_app` and `apps/desktop_app`
- Verified `flutter build apk` for `apps/android_app`

## Next Steps

- Optionally rerun `flutter build linux` in `apps/desktop_app` on this host to confirm the desktop bundle after the identifier rename