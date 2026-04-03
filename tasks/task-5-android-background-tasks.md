# Android Background Tasks

## Goal

Move Android model loading and speech generation off the UI isolate into a reusable long-running task system that keeps the app responsive and shows active tasks in the UI.

## Current Status

- Implementation complete in code and validated with `flutter analyze`, `flutter test`, and `flutter build apk --debug`
- Added a generic long-running task model plus Android foreground-service task runner
- Moved speech generation to the background task service instead of direct UI-isolate synthesis
- Moved voice preloading for model switching into the same task system
- Added an in-app task list with label, elapsed seconds, and cancel confirmation

## Blockers / Unknowns

- Need real-device validation for notification permission flow and foreground-service behavior while the app is backgrounded
- Running-task cancellation is cooperative: queued tasks cancel immediately, while an in-flight native synthesis can only be discarded after the current step returns

## Next Steps

- Run the Android app on a device and confirm generation continues after backgrounding the app
- Verify task cancellation UX on device for both queued and running tasks
- Decide whether model download/install should move into the same generic task framework later