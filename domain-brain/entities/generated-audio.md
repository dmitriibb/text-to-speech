# GeneratedAudio

## Definition

A local `.wav` artifact produced by successful synthesis and then reused for playback, export, or sharing.

## Core Properties

- local file path
- sample rate
- source model
- source text

## Ownership

- Samples are produced by `TtsService`
- File creation is coordinated by app state in desktop and Android apps
- Playback/export/share is owned by platform-specific app services

## Notes

- `GeneratedAudio` is currently a project concept, not a dedicated shared Dart class.
- Android stores generated audio under app-support storage.
- Desktop uses a temp file for generation, then can export a copy to a user-selected path.