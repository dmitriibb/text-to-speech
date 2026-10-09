# Russian phone-call implementation

Status: implementation complete, archived 2026-10-09. User testing starts now.

Completed D1/D3 and all remaining D4–D9 engineering: pinned desktop VoxCPM2
reference routing, truthful capabilities, safe sequential per-turn lifecycle,
retry/cancel/revision checks, shared transcript/project/timing controls, streamed
conversation renderer, both app preview/export adapters and a reproducible Audacity
3.7.7 phone macro. D10 technical verification/documentation are complete.

Verification: 115 automated tests plus the opt-in real CPU harness passed; four
analyzers clean. Real three-actor inference/retry/reload/render and Audacity
export/save/reopen reproduced the phone samples exactly. Ten-minute rendering
is covered automatically. Android debug APK built with Java 17. Windows native
build requires the missing Visual Studio C++ toolchain.

D2/M1 voice selection and D10/M5 listening/native-device acceptance were deferred
by the user until implementation finished and remain unclaimed. Longer new-script
listening cases are ready for user testing. AMD is separate; task 19 retains its
Home/German/GPU scope. Runtime/model/media caches remain ignored and retained.

See [workflow](../docs/russian-phone-call-workflow.md),
[verification](../tasks/phone-call-audio/implementation-verification.md) and
[plan](../tasks/phone-call-audio/plan.russian-dialogue.md).
