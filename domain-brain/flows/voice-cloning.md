# Voice Cloning

- Voice cloning is an Extended desktop-only flow exposed through the Voice Lab screen.
- Import starts from `Import WAV File`, which opens the system file chooser and restricts selection to `.wav` audio.
- The import dialog stores the chosen path as read-only UI state; users should not need to type filesystem paths manually.
- Import succeeds only when the user provides a voice name and the chosen file still exists at import time.
- A successful import copies the reference clip into `~/.tts_app/voice_library` and adds a metadata entry to `voices.json`.
- Imported voices can be previewed, deleted, and used as reference audio for Pocket TTS cloned synthesis tasks.
