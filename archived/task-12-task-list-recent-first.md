# Task List Recent-First Ordering

## Goal

Keep the newest long-running tasks at the top of the shared task list instead of appending them to the bottom.

## Current Status

Completed. The shared `TaskManager` now sorts long-running tasks by newest `startedAt` first, the regression test covers mixed-status ordering, and the long-running-task domain docs record the recent-first rule.

## Scope

- Change the shared task ordering so more recently created tasks render first.
- Add a regression test that covers mixed task statuses.
- Update the relevant domain-brain docs for the task-list ordering rule.

## Result

- New long-running tasks stay at the top of the shared task list on desktop and Android.
- Older tasks remain visible below newer ones regardless of status.
- Shared tests passed after the ordering change.
