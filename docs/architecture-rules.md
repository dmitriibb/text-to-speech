# Architecture Rules

Updated: 2026-04-04

This document defines the architectural rules and goals for the text-to-speech monorepo. All contributors and agents must follow these rules when implementing features.

## 1. Shared-First Principle

All applications must reuse the same components and services whenever possible.

- **Services** (TTS engine, model management, audio playback control, long-running task management) belong in `packages/tts_core/`.
- **UI components** (buttons, toggles, dialogs, progress indicators, task panels) belong in `packages/shared_ui/`.
- App-specific directories (`apps/desktop_app/`, `apps/android_app/`) should contain only platform-specific glue code, platform configuration, and entry points.
- Before creating a new widget or service inside an app directory, check whether it can be placed in a shared package instead.

### Platform-Specific Abstractions

When a shared component needs platform-specific behavior (e.g., background threads, file system paths, audio output):

- Define an **abstract interface** in the shared package.
- Provide **platform implementations** that the app injects at startup.
- The shared component must never import platform-specific packages directly.

Example: a `BackgroundTaskRunner` interface in `tts_core` with a `MobileBackgroundTaskRunner` and `DesktopBackgroundTaskRunner` supplied by each app.

## 2. UI Consistency

- Desktop and mobile apps must use the **same UI elements** for shared functionality: same button styles, same toggle styles, same layout patterns.
- `packages/shared_ui/` is the single source of truth for reusable widgets.
- Platform differences (e.g., navigation patterns, screen size adaptation) are acceptable, but the core controls and visual identity must be consistent.

## 3. Basic Functionality

**Basic functionality** is the feature set that must exist in **both** the desktop app and the mobile app. It must look and work identically on both platforms wherever technically possible.

### Current Basic Features

- Model catalog browsing and model installation.
- Text-to-speech synthesis with the standard (VITS/Piper) model.
- Audio playback and export.
- About / licensing screen.

### Basic Functionality Rules

1. Every Basic feature must be implemented in `packages/tts_core/` and/or `packages/shared_ui/`. App directories contain only the platform wiring.
2. UI for Basic features must use shared widgets from `packages/shared_ui/`.
3. When a Basic feature requires platform-specific work (e.g., background threads), the shared layer defines the interface and both apps provide an implementation.
4. **Long-running tasks** are a Basic feature: any action that may block the UI must run off the main thread. The UI for task progress (indicators, cancel buttons, status messages) must be identical on desktop and mobile. The underlying concurrency mechanism (Dart isolates, platform threads, Android foreground services) may differ per platform, but the user-facing behavior and controls must be the same.

### Adding a New Basic Feature

When implementing a new Basic feature:

1. Implement the service logic in `packages/tts_core/`.
2. Implement the UI components in `packages/shared_ui/`.
3. Wire them into both `apps/desktop_app/` and `apps/android_app/`.
4. Verify that the feature works identically on both platforms.

## 4. Extended Functionality

**Extended functionality** is the advanced feature set available **only in the desktop app**. It is not planned for the mobile app.

### Extended Functionality Rules

1. Extended features must **not replace** Basic functionality. They extend the desktop app with additional controls and options.
2. Extended UI must reuse the same design language (buttons, toggles, typography) as Basic UI. No separate visual style.
3. Extended features live in `apps/desktop_app/` (or a dedicated `packages/tts_extended/` package if the code becomes large enough to warrant it).
4. Extended features must not break or interfere with Basic features. A user who ignores Extended controls should have the same experience as on mobile.

### Planned Extended Features

- **Advanced model support**: larger, higher-quality TTS models beyond the standard VITS/Piper set.
- **GPU acceleration toggle**: option to run inference on CPU or GPU (AMD Radeon via ROCm, NVIDIA via CUDA).
- **Voice tuning**: adjust tone, expression, and style parameters (e.g., happy, friendly, narrator, calm, enthusiastic).
- **Voice cloning**: clone a voice from a sample recording for personalized synthesis.

## 5. Package Responsibilities

| Package | Scope |
|---|---|
| `packages/tts_core/` | Shared services: TTS engine, model management, audio logic, background task interfaces, validation |
| `packages/shared_ui/` | Shared Flutter widgets: buttons, dialogs, progress indicators, task panels, screen layouts |
| `packages/model_catalog/` | Approved model definitions (JSON) |
| `packages/quality_suite/` | Benchmark texts and quality validation |
| `apps/desktop_app/` | Desktop entry point, platform wiring, Extended features |
| `apps/android_app/` | Mobile entry point, platform wiring |

## 6. Dependency Direction

```
apps/desktop_app  ──→  packages/shared_ui  ──→  packages/tts_core
apps/android_app  ──→  packages/shared_ui  ──→  packages/tts_core
apps/desktop_app  ──→  packages/tts_core  (direct, for Extended features)
```

Apps depend on shared packages. Shared packages never depend on apps. `shared_ui` may depend on `tts_core`. `tts_core` must not depend on `shared_ui`.
