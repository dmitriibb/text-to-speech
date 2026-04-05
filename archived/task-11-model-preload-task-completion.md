# Model Preload Task Completion

## Goal

Ensure model-selection preload tasks finish and leave the task list once the background model load has actually completed or failed.

## Current Status

Completed. The shared isolate executor now keeps its result listener alive for the full executor lifetime, so `model-loading-*` tasks receive completion events and leave the active task list once the background load finishes.

## Scope

- Fix the shared background task result delivery used by model preload.
- Add a regression test for async task completion in `TaskManager`.
- Verify the task lifecycle no longer stays stuck after model selection.

## Next Steps

Issue complete and archived.
