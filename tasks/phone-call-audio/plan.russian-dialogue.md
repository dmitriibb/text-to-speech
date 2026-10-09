advanced-planning

# Russian dialogue and complete audio export

Parent: [macro plan](plan.macro.md), stages M1–M5. Progress: [checklist](plan.russian-dialogue.steps.md).

Implementation is complete through D9, with D10 engineering verification and
workflow documentation complete. The desktop VoxCPM2 path, shared project/lifecycle/
renderer, both app adapters and reproducible Audacity preset are ready for user
testing. D2 voice/engine selection and D10 listening/physical-device acceptance
remain user gates, deferred until implementation finished as requested. No listening
score or AMD success is claimed. See [verification](implementation-verification.md)
and the [workflow guide](../../docs/russian-phone-call-workflow.md).

## Objective and boundaries

Turn the existing Dialog screen into a reliable way to produce a clean Russian conversation WAV with independently assigned actor voices, then obtain a phone-sounding copy through free Audacity. Reuse line generation, task progress, the shared model settings modal, and generated-audio storage.

This plan covers shared dialogue/project/render behavior and one chosen desktop model backend. ROCm tuning is in the separate AMD plan. It does not require a timeline editor, overlap support, a new Voice Lab screen, all candidate models, or an in-app effects processor.

## Decisions and dependencies

- Begin with VoxCPM2 evaluation; its backend exists, but the real pinned runtime and Russian quality need validation. Keep OmniVoice/Qwen as conditional alternatives defined in the macro plan.
- Depend on `tasks/task-19-voxcpm2-support.md` for VoxCPM2 model settings/routing rather than duplicate the implementation. Dialog completion alone does not finish all Home/German validation requirements of task 19.
- Actor profiles own their selected settings snapshot. Global per-model settings provide defaults; subsequent actor edits do not overwrite another actor or Home/Live settings.
- Stable voice references/presets are required for a whole conversation. A fresh random/design voice per turn is not suitable.
- Each generation uses an immutable request snapshot. Final render uses a separate immutable ordered snapshot. Background results must match the current revisions.
- Large-model jobs run sequentially by default. Local sherpa-onnx can retain its existing configurable worker behavior.
- Final output is mono PCM WAV at a declared render sample rate, initially 48 kHz. Inspect actual input headers and resample correctly; do not change only the WAV header or concatenate whole file bytes.
- Keep original generated clips and a clean master. Apply the phone effect once to a copy of the assembled conversation.
- Short pauses and manual overrides are sufficient initially. Timing is part of the render, not delays between player operations.
- Target implementation locations: shared models/services in `packages/tts_core`; shared controls in `packages/shared_ui`; backend adapter and capability injection in `apps/desktop_app`; save/share/storage glue in both apps.

## Ordered implementation steps

### D1 — Build the Russian evaluation script and acceptance rubric (M1)

Add a small versioned fixture to the quality suite with about 20 short turns, initially two actors and a separate three-actor sample. Include examples such as:

```text
Анна: Алло, Сергей? Ты меня слышишь?
Сергей: Да, слышу. Привет! Что случилось?
Анна: Встречу перенесли на пятницу, на половину шестого.
Сергей: Подожди, на эту пятницу или на следующую?
Анна: На эту. Я ещё отправлю тебе адрес сообщением.
Сергей: Хорошо, спасибо. Тогда до встречи!
```

Also cover `ё`, names/surnames, dates, prices, abbreviations, a telephone number, hesitations, a very short answer, a long turn, punctuation, and a colon inside spoken text. Preserve the original script; any pronunciation-friendly text is a separate explicit override, not an invisible rewrite.

Score pronunciation, conversational delivery, actor identity, and intelligibility after phone EQ on a 1–5 scale. Suggested target: at least 4/5 on these dimensions, no missing/repeated words or spoken actor labels, and zero voice swaps in the accepted sample. These are proposed listening gates, not measured facts. Save filenames, model revision, actual settings, hardware/device, cold load time, warm synthesis time, output duration, and failures in a report.

Verification: the fixture covers the required cases and the report schema distinguishes quality from runtime performance.

### D2 — Run real synthesis and freeze two actor voices (M1)

Use an isolated model environment and a pinned checkpoint revision. Start with a short real VoxCPM2 inference and inspect the generated WAV, not only `/health` or mocked API tests. Validate reference/style/seed arguments against installed `voxcpm==2.0.3`; validate Cyrillic preservation and any text-normalization helper. Disable optional denoiser/optimization for the first smoke test.

Where no samples exist, design several synthetic Russian voices once, select two contrasting voices, then reuse clean reference clips and exact transcripts if the model supports that. Use normal speech references, before any phone effect. A fixed seed can help reproducibility but does not replace a fixed voice reference. Use model-specific reference duration/rate limits verified during evaluation.

If VoxCPM2 is insufficient, compare the existing OmniVoice path with `language=ru` and supplied `ref_text`; avoid loading Whisper when unnecessary. Qwen comparison is conditional: test 1.7B CustomVoice for ease of stable identities or Base with Russian references for accent/identity. Use its supported-language/speaker API; map canonical `ru` to backend-specific `Russian` where required. Do not assume the 0.6B variants have the same instruction control as 1.7B.

A small native AMD smoke test can be attempted here if the environment is already available. If it needs extended setup/debugging, use CPU or an existing reachable backend to complete voice evaluation and defer acceleration to M6. If no usable powerful engine is available, a verified Russian Piper pair can validate plumbing, but does not certify the desired large-model quality.

Verification: a real report and saved samples establish the chosen engine, two persistent actor identities, workable generation time, and the precise settings actually supported. User listening feedback can refine the selection; do not claim a model is best solely from its published benchmarks.

### D3 — Define synthesis targets and independent actor profiles (M2)

Introduce the smallest shared contracts needed to represent a local installed model or an injected desktop backend target. Preserve current local model IDs and decoding of older settings. Catalog entries describe runtime/platform/capabilities; backend readiness depends on the selected endpoint/model, not ONNX `tokens.txt` or a fabricated `modelDir`.

Add an actor ID/profile containing display name, target/model ID, voice/preset or reference asset identity, reference transcript, generation language, speed, output gain, and JSON-safe model extensions. Model defaults are copied into a new profile, while each actor keeps its own effective values. Keep per-model settings as the default mechanism outside actor overrides.

Reconcile legacy Dialog volume `1–10`, default `7`, with generic settings gain: migrate/convert once, choose one effective gain value, and do not multiply both gains. Retain a sensible conversation speed default; applying speed to one actor must not unexpectedly change all actors.

Keep reference bytes in an app-managed project/reference directory, not in settings JSON. Persist relative asset IDs/paths and content hashes; desktop clients upload reference bytes through the existing multipart API so WSL/remote backends do not depend on Windows-local paths.

Verification: two actors using the same model retain distinct reference/style/speed values through editing, model switches, serialization, and reload; the shared packages have no dependency on desktop services.

### D4 — Wire the selected backend and truthful model controls (M2)

Register the selected Extended target in the desktop selector, using the existing settings modal extension hook for references/style. The Backend models screen remains connection/device configuration. Do not create one cloned catalog model per actor to evade shared-state collisions.

Route backend-selected turns through the common `/health`, `POST /jobs`, polling, and result-download lifecycle. Keep model-specific values inside `settings`. Add bounded request/poll deadlines, cancellation-aware waiting, actionable connection errors, and local WAV validation. Readiness must distinguish server reachable, engine loadable, and model loaded; first-load progress should remain visible.

Inspect the actual engine behavior: current VoxCPM2 accepts API speed/language fields without using speed in `generate()`. Apply advertised controls through a real engine capability or tested pitch-preserving postprocessing. Disable/explain unsupported controls if necessary and update the capability/UI assumptions rather than silently ignore them. Russian can be inferred from text for VoxCPM2, but an explicit language selector must reflect real behavior. Apply effective actor gain once to the stored clip.

Update catalog metadata/asset copies and tests, plus relevant licensing evidence, when introducing app-visible targets. Backend metadata must not cause Android to attempt Python-model installation; desktop-only controls are injected explicitly. Add a Russian Piper fallback entry only if chosen by D2 or needed for Android Basic verification, using official artifacts and the existing approval process.

Verification: the app generates Russian turns using the selected backend and local models still work; submitted values demonstrably affect output where the UI says they do.

### D5 — Add safe per-turn generation, retry, and cancellation (M2)

Add a single inference queue/lock per backend model; current VoxCPM2 initialization locking does not serialize `generate()` calls, and `JobStore` currently launches a background task for every submitted job. Do not assume four frontend workers or several actors imply safe concurrent GPU inference.

Give each project/run/turn a stable identity and revision. Capture text, actor settings, reference hash, target/model revision, and effective generation settings in each queued request. Late results from cancelled runs, removed turns, reimports, or actor edits must be discarded/cleaned up rather than attached to a reused `dialog-line-N` ID.

Support Generate missing/changed lines and Retry selected line, retaining other valid clips. Changing an actor invalidates that actor's affected clips and the current render; changing timing invalidates only the render. Keep valid previous renders as clearly identified historical artifacts, or replace them explicitly after success.

For backends without true interrupt support, cancellation stops queued dispatch and polling/attachment, reports that in-flight computation may finish, and prevents late-file resurrection. Add server cancellation/cleanup only where needed; do not promise instant mid-kernel interruption. Give completed server artifacts an explicit cleanup policy separate from durable app-owned downloads.

Verification: mocked lifecycle tests cover timeout/disconnect/cancel/late success; a real multi-turn run stays responsive, respects queue limits, and retry does not change the other actor's clips.

### D6 — Add transcript review, project persistence, and timing (M2–M3)

Reuse `Speaker: text` clipboard import. Show skipped/invalid rows with source line numbers before generation; preserve Cyrillic, `ё`, UTF-8, and the text after the first colon. Allow editing a turn and explicit removal/exclusion without reparsing the entire project. A minimal shared edit dialog is enough; keep the compact line list.

Persist a versioned project JSON with actor profiles, ordered turns, effective text overrides, clip identities/paths/statuses, and timing. On reload, validate files/reference assets and mark missing/stale clips accordingly rather than treating JSON as proof of readiness. Handle corrupt project data without losing a previously exported WAV.

Add a default inter-turn pause, initially around 250 ms, and per-turn override with a bounded range (proposed 0–2000 ms). Avoid compulsory uniform timing; users can tune awkward turns. Trim only verified leading/trailing silence conservatively, leaving consonants/breaths intact; allow trimming to be disabled. Defer true overlap/interruption editing. Save the exact timings in the render manifest.

Verification: project reload preserves a three-speaker script; an edit invalidates only affected generation plus render; changing pauses requires no TTS regeneration.

### D7 — Implement the shared conversation renderer (M3)

Add a background render service in `tts_core` using a shared interface for any platform-dependent audio decoder/resampler. Prefer a portable PCM WAV path; keep desktop shell tools out of shared Basic services. Inspect the selected backends' actual PCM formats before deciding the smallest supported decoder set, with clear errors for unsupported/corrupt input.

Render an ordered snapshot of included non-empty turns. Require a valid, current, complete clip for each; list missing/failed turns instead of silently skipping them. Decode samples, convert channels, use a verified resampling implementation with anti-aliasing when needed, insert sample-accurate silence, apply conservative boundary fades only outside audible speech, then write a single valid mono PCM WAV. Respect gains already baked into line files. Avoid per-line loudness normalization that amplifies tiny replies/noise; apply final peak/headroom handling to the conversation.

Proposed output: mono 48 kHz 16-bit PCM WAV for interoperability, peak at or below -1 dBFS, plus a manifest containing project revision, actor/turn IDs, input hashes, timeline offsets, render rate, and processing settings. These are engineering defaults, subject to listening. Do not use a resampler to simulate speaking speed with unintended pitch changes.

Write to a unique temporary destination and atomically publish only after successful validation. Stream/process bounded chunks for longer conversations. Cancellation, failure, or a source edit during render must not replace a known-good export with a partial/current-looking file. Rendered conversation records must not count as new per-model synthesis statistics a second time.

Verification: meaningful fixtures test order/content, mixed sample rates/channel counts, exact duration including pauses, clipping bounds, corrupt/missing input, cancellation, and revision changes. A saved mixed-source WAV plays correctly in another audio application.

### D8 — Wire final preview and export on desktop and Android (M3)

Add shared Render conversation, preview, and Save/share controls with progress/cancel state and stale/missing-line feedback. Final preview plays the rendered WAV so it matches the exported timeline; existing per-line preview remains useful for repairs. Honor single-active-audio behavior across modes.

Store the rendered WAV and metadata in the existing generated-audio flow; source clip retention/ownership must be explicit so dismissing one artifact cannot orphan/delete another project's required files. Save an independent copy at the user's chosen desktop destination or share the same finished file via Android's system sheet. Export cancellation does not delete the internal master.

Wire Basic profile/edit/timing/render functionality into both apps using local models on Android. Extended backends/reference controls remain desktop-only, which must be described plainly in documentation. Existing Android Dialog/state duplication is glue to converge, not a reason to put new rendering logic in both app states.

Verification: both apps can render and replay the same local-model project and export/share an equivalent WAV. Desktop additionally completes the powerful-model path. Report shared parity, platform save/share differences, and any remaining wiring without claiming untested parity.

### D9 — Save and test a free Audacity phone preset (M4)

Create a concise `docs/russian-phone-call-workflow.md` guide and a saved Audacity preset/macro or exact settings table. Link [Audacity](https://www.audacityteam.org/), [Filter Curve EQ](https://manual.audacityteam.org/man/filter_curve_eq.html), and [Compressor](https://manual.audacityteam.org/man/compressor.html) for the tools. Verify installed-version control names when executing this step.

Starting recipe, proposed by this plan and to be tuned by listening:

1. Import a copy of the clean master; retain the source outside the editing project.
2. Keep mono; shape a narrowband telephone curve with most energy between roughly 300 and 3400 Hz, using smooth roll-offs.
3. Apply mild compression, starting around 2:1–3:1 if needed; set threshold from measured input levels and limit output peaks to around -1 dBFS.
4. Optionally add very quiet continuous channel noise after filtering, initially around -45 dBFS RMS. Keep it disabled until the clean filtered version is accepted; avoid overwhelming short Russian consonants or turn gaps.
5. Export `conversation-phone.wav`, initially mono 16-bit PCM at 16 kHz or the clean render rate. Export an 8 kHz variant only for a deliberate classic narrowband/codec target; sample-rate reduction alone is not a complete telephone effect.

Compare clean and filtered versions at similar loudness. Start with both actors filtered as a conventional recorded call. For a local-recorder perspective, preserve one actor cleaner and filter the remote actor using separate tracks if desired. For a modern wideband mobile-call sound, use a gentler wider curve rather than the classic narrowband preset.

Codec coloration, ring tones, clicks, dropouts, room noise, and heavier distortion are optional. If adding a telephony codec later, verify encode/decode availability and listen to the result; do not substitute arbitrary bit crushing. Audacity is the required free completion route here; a later FFmpeg script or in-app preset can automate an already accepted chain.

Verification: a real processed WAV remains fully understandable, both voices remain distinguishable, effects reproduce after reopening, and the clean master is preserved.

### D10 — Complete end-to-end acceptance and documentation (M5)

Render/export a 2–5 minute two-actor Russian call, a short three-actor call, and a roughly 10-minute conversation. Repair one intentionally failed/changed turn and rerender without regenerating unrelated turns. Verify names/numbers against the script, listen across every transition, and confirm no labels/instructions are spoken, no dropped/duplicated turns, no clipping/clicks, and stable actors after phone filtering.

Save final sample paths, quality feedback, model/actor/project versions, generation/render time, and exact effect preset. Document model setup, transcript format, profile creation, retry, final render, Audacity export, and known performance limits. Keep large model caches and generated/reference media out of git; commit only small synthetic test fixtures needed for meaningful tests.

Run relevant core/shared UI/app/backend tests and analysis for actual changes. Update `flow-index.yaml` and the smallest matching domain-brain documents: local-synthesis, model-settings, audio-output, voice-cloning, model catalog/readiness, generated-audio ownership, synthesis/playback lifecycles, and edge cases. Reconcile existing task 19 progress accurately. Archive completed task records immediately; leave the AMD stage unchecked until proven.

Verification: priority 1 produces both clean and phone WAVs and the documented workflow can be repeated with a different Russian script. All Basic implementation is accounted for on desktop/mobile; Extended runtime differences are explicit.
