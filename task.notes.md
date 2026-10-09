# Task Notes

- Priority: Russian phone-call audio comes first; AMD GPU acceleration comes second.
- Decision: Reuse Dialog; export one clean conversation WAV, then apply a repeatable free Audacity phone effect.
- Plan: Russian-dialog engineering is complete; archived task 25. `tasks/phone-call-audio/` retains user listening/voice/device acceptance and the separate AMD plan. See `docs/russian-phone-call-workflow.md` and `tasks/phone-call-audio/implementation-verification.md`.
- Constraint: Actor references/styles must remain independent when multiple speakers use the same model.
- Constraint: Final conversation export must reject missing/stale turns rather than silently skip them.
- Dependency: Reuse task 19 for VoxCPM2 integration; select the engine after real Russian listening tests.
- Warning: Official RX 9070 XT Windows support does not prove model compatibility; validate actual ROCm inference.
- Constraint: Basic dialogue/render changes belong in shared packages and both apps; Python/ROCm integration remains desktop Extended.
- Constraint: Skip optional user-validation gates and keep building; say `USER ACTION REQUIRED` only for unavoidable user-dependent blockers.
- Runtime: VoxCPM2 backend venv now uses CPython 3.10.22 from ignored `artifacts/russian-dialogue/python-runtime/`; preserve that base interpreter or recreate the venv. Global Python 3.10.0 cannot run current Pydantic.
- Evaluation: Real two/three-actor CPU clips and clean/phone previews are under `artifacts/russian-dialogue/`; candidate references are reusable by hash, but listening and engine selection remain pending.

- Completion: shared project/edit/timing/retry/render controls are wired on both apps; pinned VoxCPM2/reference controls are desktop Extended.
- Verification: real three-actor CPU adapter/retry/reload/render and Audacity 3.7.7 phone export/reopen passed; listening remains user acceptance.
- Build: Android debug APK builds with isolated Java 17 under ignored artifacts. Windows executable build requires the missing Visual Studio C++ toolchain; no system settings were changed.
