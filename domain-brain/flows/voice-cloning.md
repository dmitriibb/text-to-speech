# Voice Cloning

- Voice cloning is an Extended desktop-only flow exposed inline in the desktop home screen when the Advanced Functionality toggle is enabled.
- The Basic panel stays on the left and the Advanced Voice Lab panel stays on the right with shared text state.
- The Advanced panel always shows the `Voice Cloning` toggle, but cloning-specific controls stay hidden until that toggle is enabled.
- Voice Lab does not own a separate synthesis text field; cloned synthesis always uses the text entered in the Basic panel.
- Voice cloning mode depends on a ready Pocket TTS model and is disabled until that model is installed.
- Voice Lab separates cloning into two desktop-only engines: `Pocket TTS` and `OpenVoice`.
- When Pocket TTS is selected outside clone mode, regular synthesis falls back to the model's bundled default reference clip instead of the imported voice library.
- Enabling voice cloning automatically switches the main desktop model selector to Pocket TTS so cloned synthesis uses the correct runtime.
- Import starts from a single `Import Audio File` action, which opens the system file chooser and accepts `.wav` and `.mp3` audio.
- The import dialog stores the chosen path as read-only UI state; users should not need to type filesystem paths manually.
- Import succeeds only when the user provides a voice name and the chosen file still exists at import time.
- Voice Lab detects the imported sample format automatically; if the user selects an `.mp3`, desktop converts it to `.wav` at import time before saving it into the voice library.
- A successful import stores the normalized reference clip as `.wav` under `~/.tts_app/voice_library` and adds a metadata entry to `voices.json`.
- Imported voices can be previewed, deleted, and used as reference audio for Pocket TTS cloned synthesis tasks.
- OpenVoice is configured by a manual backend URL in Voice Lab and remains usable even when Pocket TTS assets are unavailable.
- The desktop app polls OpenVoice jobs at 1s, 2s, 3s, and so on up to a 10s maximum interval.
- The OpenVoice backend stores MVP job state in `apps/open_voice_be/storage/` with `.json` job metadata and `.wav` reference and result audio files.
- The current OpenVoice implementation provides health checks, async preview-job submission, and result polling, but real inference is still not connected and preview jobs fail with an explicit backend error until the engine is wired.
