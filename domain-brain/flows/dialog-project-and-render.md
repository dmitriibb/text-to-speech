# Dialog projects and complete conversation output

DialogWorkspace in tts_core owns Basic transcript/actor state, generation
snapshots, project JSON, timing and render state. Both apps inject writable
storage and local synthesis, and use the same shared panel. Desktop injects the
VoxCPM2 Extended target and reference-picker adapter. Android cannot dispatch
backend targets from a saved project; it reports that a local model is required.

- Every import creates a new project and unique turn identities. Each text edit
  advances that turn's revision. Actor edits invalidate only that actor's clips.
- Generate missing/changed and retry dispatch sequentially. Requests capture
  text, actor settings/reference hash and checkpoint revision. A late response
  attaches only if its project/turn/actor fingerprint still matches.
- Cancel stops queued dispatch, local tasks and backend polling/attachment;
  backend kernels may finish. Server DELETE prevents late resurrection and
  removes references/results once inference is safe. Server artifacts expire
  after seven days on startup if abandoned.
- Actor gain is baked into each clip once. Timing/inclusion edits invalidate
  only the render. Original text and explicit pronunciation overrides persist
  separately. Pauses range from 0 to 2000 ms, default 250 ms.
- Project JSON is versioned, atomically saved, and reload validates relative
  paths/hashes. Files are managed separately from JSON. Corrupt JSON retains
  current work; stale/missing references or clips require repair.
- There is one saved active project per app. The Save/Reload controls and
  startup use its app-private dialog_project directory. Historical owned
  clips/references/renders are retained for recovery; no project browser or
  portable archive importer is implied.
- Render requires every included non-empty turn to have a current complete
  clip. Missing/failed turns are errors, never silently skipped.
- ConversationRenderer runs in an isolate, reads at most 128 MiB per input,
  mixes 1–8 PCM channels to mono, supports integer PCM8/16/24/32 and float32,
  and resamples with a 64-tap windowed-sinc anti-alias filter. Output is streamed
  through a temporary float file, followed by global peak attenuation and a
  mono 48 kHz PCM16 WAV. RIFF-size, corrupt input and disk errors fail explicitly.
- Optional trim removes near-digital silence only and retains 20 ms boundaries.
  No gain or audible-boundary fade is applied a second time. No overlap or
  pitch-changing speed processing is present.
- Cancellation/project changes discard a render's unique temporary output;
  previous masters remain historical. Manifests record input hashes, actor/turn
  IDs, revisions, offsets and exact processing/timing.
- Master preview/seek uses the exact exported timeline. Sequence/line auditions
  are separate conveniences. Playback still obeys one-active-audio across modes.
- Task-list artifacts are independent copies. Removing them cannot orphan a
  saved project. Assembly has no input-character/model stats and cannot count
  as a second synthesis. Desktop saves a copy; Android shares the finished WAV.
- Phone processing is a separate Audacity copy workflow; clean masters and
  references remain unchanged. Preset parameters are technically tested in
  Audacity 3.7.7; voice quality/intelligibility remain listening acceptance.
