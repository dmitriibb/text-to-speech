# Dialog Generation Identity

## Goal

Fix Dialog generation so rapidly queued lines never share the same task ID or output WAV path.

## Current Status

Completed. Task IDs now include a monotonic counter, generated audio filenames include a monotonic counter, and a regression test covers rapid synthesis submissions.

## Scope

- Make `TaskManager` task IDs unique even when submissions happen in the same clock tick.
- Make app-generated WAV output paths unique even when dialog lines are queued rapidly.
- Document the edge case in domain-brain.
