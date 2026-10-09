# Russian phone-call audio planning

## Goal

Inspect the existing application, research Russian TTS and AMD compatibility, and create an advanced macro plan plus detailed feature plans/checklists.

## Current status

Complete: planning deliverables created and validated on 2026-10-09. Audio generation, implementation, model downloads, and GPU validation were not performed. The recording/GPU execution roadmap remains active under `tasks/phone-call-audio/`.

## Deliverables

- [Macro plan](../tasks/phone-call-audio/plan.macro.md) and [checklist](../tasks/phone-call-audio/plan.macro.steps.md).
- [Russian dialogue/export plan](../tasks/phone-call-audio/plan.russian-dialogue.md) and [checklist](../tasks/phone-call-audio/plan.russian-dialogue.steps.md).
- [AMD acceleration plan](../tasks/phone-call-audio/plan.amd-acceleration.md) and [checklist](../tasks/phone-call-audio/plan.amd-acceleration.steps.md).

## Decisions and next work

- First priority: clean multi-actor Russian conversation export followed by a free Audacity phone effect.
- First engine to evaluate: existing VoxCPM2 backend; OmniVoice/Qwen are conditional comparison paths.
- Second priority: actual RX 9070 XT PyTorch/ROCm inference, with native Windows first and WSL fallback.
- Continue with D1/D2 voice evaluation. Reuse task 19 for VoxCPM2 integration rather than duplicate it.
- All implementation checkboxes remain unchecked. Plan marker, flat checklist, local links, and whitespace validation passed.
