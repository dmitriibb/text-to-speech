# Task Notes

- Decision: Ubuntu desktop validation is sufficient for now; do not block Phase 2 planning on Windows.
- Constraint: Current development machine is an Ubuntu laptop with Android Studio and Android SDK installed; emulator-based Android validation is now available.
- Decision: For Android Phase 2, prefer a physical Android device before emulator setup on this host.
- Rule: Keep `domain-brain/` and `flow-index.yaml` synchronized with domain-facing code, behavior, and state changes.
- Warning: Current desktop model install uses shell tar extraction and must be replaced for Android support.
- Warning: Redistribution-safe default voice is still unresolved; Android work may continue with a development model only.
- Decision: Current runtime only exposes speed, speaker selection, and Pocket reference-audio cloning; real mood or tone tuning needs a new model runtime.
- Decision: Easiest future catalog additions for richer voice choice are Kokoro multi-language and Piper LibriTTS-R multi-speaker models.
