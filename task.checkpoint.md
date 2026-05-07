# Task Checkpoints

## Checkpoint 1
- Added shared live TTS chunking that splits by target word count and rounds each chunk up to the end of the current sentence
- Added a shared live TTS session service that pre-generates upcoming chunks, keeps the next chunk ready, and plays chunks sequentially without overlap
- Added a shared highlighted live text editor with a `Live` toggle, chunk-size input, play or stop control, larger scrollable input, and chunk-state highlighting
- Wired desktop and Android Home state to start, stop, auto-advance, and clean up live chunk playback using the shared session flow
- Updated flow-index and domain-brain docs for live synthesis and temporary live chunk playback behavior
- Added targeted `tts_core` and `shared_ui` tests covering chunk splitting, live session scheduling, and editor highlighting
