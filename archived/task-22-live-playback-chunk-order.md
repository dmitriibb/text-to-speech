# Task 22: Live playback chunk order

## Goal

Ensure Live mode always starts at the cursor's first chunk and plays chunks in text order even when concurrent generation finishes out of order.

## Status

Completed.

## Cause and fix

The shared session selected any ready chunk. Concurrent synthesis could finish chunk 2 before chunk 1, causing playback order 2 then 1. Playback selection now waits for the earliest unplayed chunk to become ready.

## Verification

- Added a shared regression test that completes chunk 2 before chunk 1.
- Dart formatting and `git diff --check` passed.
- Flutter test execution was attempted repeatedly, including with `--no-pub`, but the runner hung before producing test output in this environment.
