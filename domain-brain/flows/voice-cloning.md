# Voice Cloning

- Voice cloning is an Extended desktop-only flow exposed inline in the desktop home screen when the Advanced Functionality toggle is enabled.
- The Basic panel stays on the left and the Advanced Voice Lab panel stays on the right with shared text state.
- Voice Lab does not own a separate synthesis text field; cloned synthesis always uses the text entered in the Basic panel.
- Voice cloning mode depends on a ready Pocket TTS model and is disabled until that model is installed.
- Enabling voice cloning automatically switches the main desktop model selector to Pocket TTS so cloned synthesis uses the correct runtime.
- Import starts from `Import WAV File`, which opens the system file chooser and restricts selection to `.wav` audio.
- The import dialog stores the chosen path as read-only UI state; users should not need to type filesystem paths manually.
- Import succeeds only when the user provides a voice name and the chosen file still exists at import time.
- A successful import copies the reference clip into `~/.tts_app/voice_library` and adds a metadata entry to `voices.json`.
- Imported voices can be previewed, deleted, and used as reference audio for Pocket TTS cloned synthesis tasks.
