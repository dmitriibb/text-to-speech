import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/model_status_card.dart';
import '../widgets/playback_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/text_input_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F1E8), Color(0xFFE9F3F0)],
          ),
        ),
        child: Consumer<AppState>(
          builder: (context, state, _) {
            if (state.isLoadingModels) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroCard(state: state),
                  const SizedBox(height: 16),
                  const ModelStatusCard(),
                  const SizedBox(height: 16),
                  const TextInputPanel(),
                  const SizedBox(height: 16),
                  const SettingsPanel(),
                  const SizedBox(height: 16),
                  _GenerateButton(state: state),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: state.errorMessage!),
                  ],
                  if (state.hasAudio &&
                      state.synthesisStatus == SynthesisStatus.done) ...[
                    const SizedBox(height: 20),
                    const PlaybackPanel(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = state.selectedModel == null
        ? 'Install one approved English model to enable offline speech on this device.'
        : 'Ready for local generation with ${state.selectedModel!.voice.displayName}.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1D4D4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offline Android TTS',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _StatusPill(
                icon: Icons.smartphone,
                label: 'On-device only',
              ),
              const _StatusPill(
                icon: Icons.wifi_off,
                label: 'Works offline after install',
              ),
              _StatusPill(
                icon: Icons.graphic_eq,
                label: state.hasAudio ? 'Audio ready' : 'Awaiting output',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: state.canGenerate ? state.generate : null,
        icon: state.synthesisStatus == SynthesisStatus.generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.record_voice_over),
        label: Text(
          state.synthesisStatus == SynthesisStatus.generating
              ? 'Generating locally...'
              : 'Generate speech',
        ),
      ),
    );
  }
}