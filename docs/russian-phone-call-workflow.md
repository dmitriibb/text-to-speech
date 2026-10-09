# Russian conversation: clean master and phone copy

The implementation is ready for user testing. VoxCPM2 is the provisional desktop
engine; pronunciation, conversational delivery and actor identity still need your
listening acceptance. Android uses installed local models. AMD acceleration is a
separate plan and has not been validated here.

## Generate and repair the conversation

1. On desktop, start the [VoxCPM2 backend](../apps/voxcpm2_be/how-to-run.md).
   Enable it in **Backend models**, set the endpoint (normally
   `http://127.0.0.1:8011`), and check the connection. A reachable server can need
   its first model load; a loaded model is reported separately. Use the verified
   CPU baseline with `VOXCPM_OPTIMIZE=false` and `VOXCPM_LOAD_DENOISER=false`
   while testing. The default
   checkpoint is pinned to `32279effe8c19989596f05d353d1447f51d9e915`.
2. Open **Dialog** and paste lines such as:

   ```text
   Анна: Алло, Сергей? Ты меня слышишь?
   Сергей: Да, слышу. Привет! Что случилось?
   Анна: Встречу перенесли на пятницу, на половину шестого.
   Сергей: Подожди, на эту пятницу или на следующую?
   Анна: На эту. Я ещё отправлю тебе адрес сообщением.
   Сергей: Хорошо, спасибо. Тогда до встречи!
   ```

   Review the skipped-row diagnostics. The parser preserves `ё` and everything
   after the first colon. Editing a row can change the original text or supply a
   separate explicit pronunciation override. You can exclude or remove a turn.
3. Assign each actor an installed local model or **VoxCPM2 (backend)**. With
   VoxCPM2, open that actor's gear, choose a clean PCM WAV reference of 1–30
   seconds, and enter its exact transcript. The app copies and hashes the
   reference; the backend receives its bytes, so remote servers need no access
   to your local file path. Use a different persistent reference for each actor.
4. The existing candidate references are in the ignored local directories
   `artifacts/russian-dialogue/full-2026-10-09-01/` (Anna/Sergey) and
   `artifacts/russian-dialogue/three-2026-10-09-01/` (also Irina). Their intended
   transcript is:

   ```text
   Привет! Хорошо, что ты позвонил. Я сейчас дома и могу спокойно поговорить. Расскажи, как прошёл твой день.
   ```

   Listen to each reference before accepting it; these are synthetic candidates.
   References are normal speech, before any phone effect.
5. Settings belong to the actor. Volume is applied once to its stored clip;
   changing one actor leaves other actors and Home/Live defaults intact.
   VoxCPM2 exposes delivery style, guidance and inference steps. Its speed is
   fixed at 1.0; pronunciation language follows the script. Text normalization
   and denoising are off. Local models retain their supported speed/language
   controls.
6. Choose **Generate missing / changed**. Turns run sequentially with progress,
   elapsed time and **Cancel**. Cancellation prevents dispatch/attachment of
   remaining results; an already running model kernel may finish on the server.
   Use a row's **Retry this line** action to repair it without regenerating the
   other clips. Failed turns show their error in the row.
7. Set the default pause (250 ms initially) and any per-turn override (0–2000
   ms). These changes require rendering, without further TTS. Trimming is off
   initially; the optional trim removes only near-digital silence and retains
   20 ms at speech boundaries. Overlapping speakers are outside this version.

## Save, render, preview and export

**Save project** writes the current project to app-private storage.
**Reload saved project** restores it; startup also restores the latest saved
project. There is one active saved project per app in this version. Before
replacing it, save/export the WAV you need and back up the project directory if
you want its editable source. Project storage is the `dialog_project` sibling of
the app's models/generated-audio directories. It contains `project.json`, managed
references, owned clips and historical renders. It is not a portable project-file
import/export UI.

Reload verifies clip/reference hashes and the rendered WAV. Missing or changed
assets need repair. Corrupt JSON reports an error and retains current work;
exported WAV copies are independent of project JSON.

Choose **Render conversation** after every included non-empty turn is ready.
Missing/failed/stale turns block rendering and are listed in the error. The
renderer writes a mono 48 kHz PCM16 WAV with sample-accurate pauses, channel
conversion, anti-aliased resampling and global attenuation if needed to keep peaks
at or below -1 dBFS. It never increases quiet turns separately. The adjacent
manifest records revisions, actor/turn IDs, input hashes and timeline positions.
Each render uses a new destination; edits or cancellation cannot replace an old
master with a partial result.

**Preview master** and the seekable master player play this exact WAV.
**Save / share WAV** saves an independent desktop copy or opens Android's system
share sheet. Export cancellation retains the internal master. The older line and
sequence playback controls are quick auditions; the rendered master is the
authoritative timeline with pauses.

Project clips/masters and generated-audio task-list copies have independent
ownership. Dismissing or clearing task-list output does not delete saved project
sources. Assembly does not count as a second model generation in statistics.
Historical project artifacts are retained for recovery; remove/back up the
project directory only when you no longer need that editable project.

## Make the phone copy in free Audacity

Download [Audacity](https://www.audacityteam.org/). The saved
[Russian phone macro](presets/russian-phone-call.txt) was technically verified in
Audacity **3.7.7**. Other versions may change effect command names/parameters.

Import a copy of the clean master into an empty project. In **Tools → Macros**,
import `russian-phone-call.txt`, then apply it to the project. The macro selects
all audio, applies [Filter Curve EQ](https://manual.audacityteam.org/man/filter_curve_eq.html),
a mild [Compressor](https://manual.audacityteam.org/man/compressor.html), and peak
normalization. Keep the original clean WAV outside the Audacity project.

| Control | Saved value |
| --- | --- |
| Filter Curve EQ | 20 Hz: −36 dB; 100: −24; 200: −12; 300: −3; 500: 0; 2400: 0; 3400: −3; 4500: −18; 8000: −36; 20000: −48 |
| EQ interpolation / filter length | B-spline, logarithmic frequency, 8191 |
| Compressor threshold / ratio / knee | −18 dB / 2.5:1 / 6 dB |
| Compressor lookahead / attack / release | 1 ms / 10 ms / 150 ms |
| Makeup gain | 0 dB |
| Normalize | −1 dB peak, remove DC offset |
| Added noise / distortion / codec | Disabled |
| Export | `conversation-phone.wav`, mono, 16-bit PCM, 16 kHz |

The threshold is a starting value; reduce compression if the recording pumps or
sounds squeezed. Compare clean and phone versions at similar listening loudness.
Both actors are filtered. A local-recorder perspective or wider modern mobile
sound needs a different curve/track treatment. Export 8 kHz only for a deliberate
classic narrowband target; changing sample rate alone is not the phone effect.

An optional [scripting helper](../tools/benchmark/audacity_phone_preset.py) uses
Audacity's [mod-script-pipe](https://manual.audacityteam.org/man/scripting.html).
It preserves the clean input, applies the same macro, exports, saves/reopens the
Audacity project and checks that the second export reproduces the samples.
This requires an empty running project, enabled scripting, Python with NumPy and
SoundFile, and a new output path. Regular manual macro use needs no Python.

## User acceptance

Listen to the two/three-actor references and complete clean/phone conversations.
Score pronunciation, conversational delivery, actor identity and intelligibility
after phone EQ from 1–5. Suggested acceptance is at least 4/5 in each dimension,
no missing/repeated words, no spoken actor labels, and no voice swaps. Check names,
numbers, dates, `ё`, short replies and a longer recording. Also exercise cancel,
retry, edit, save/reload, preview/seek and platform save/share. These listening and
physical-device checks remain user testing; automated WAV checks cannot certify
them.

See the [implementation verification](../tasks/phone-call-audio/implementation-verification.md)
for measured results and host build limitations.
