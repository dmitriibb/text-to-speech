# Package Name Alignment

## Goal

Rename application and artifact identifiers so they use the `com.dmbb.tts` prefix.

## Current Status

- Not started
- Android still uses `com.example.android_app`
- Desktop Linux currently uses `com.texttospeech.desktop_app` as the GTK application ID
- Other platform-specific identifiers have not been fully audited yet

## Blockers / Unknowns

- Need one final naming scheme for desktop and Android artifacts
- Need to confirm whether Windows and macOS bundle identifiers also need to be renamed now

## Next Steps

- Audit all desktop and Android identifiers, package names, bundle IDs, and runner metadata
- Pick final names such as `com.dmbb.tts.android` and `com.dmbb.tts.desktop`
- Update code, native project files, and documentation together