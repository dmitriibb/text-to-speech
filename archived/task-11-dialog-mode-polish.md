# Dialog Mode Polish

## Goal

Make Dialog line rows compact and fix sequence playback so generated lines play once in transcript order without skipping or repeating rows.

## Current Status

Completed. Dialog line rows are compact single-line rows and sequence playback ignores stale stop events until the selected line has actually entered playback.

## Scope

- Render each dialog line as one narrow row: person, text, remove row icon, play icon, and status icon.
- Remove the `Remove text` line action.
- Harden Dialog sequence auto-advance against stale playback completion events.
- Update tests and domain-brain notes if behavior changes.
