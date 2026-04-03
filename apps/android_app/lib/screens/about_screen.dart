import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import '../state/app_state.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
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
            final hasReadyModel =
                state.selectedModel?.status == ModelStatus.ready &&
                state.selectedModel?.modelDir != null;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AboutHeroCard(state: state),
                  const SizedBox(height: 16),
                  _AboutSection(
                    title: 'How it works',
                    child: Column(
                      children: const [
                        _AboutRow(
                          icon: Icons.download_done,
                          title: 'Install an approved voice',
                          body:
                              'Download one supported English model to app storage before generating speech.',
                        ),
                        SizedBox(height: 12),
                        _AboutRow(
                          icon: Icons.memory,
                          title: 'Generate on device',
                          body:
                              'Speech synthesis runs locally through sherpa-onnx with no cloud dependency.',
                        ),
                        SizedBox(height: 12),
                        _AboutRow(
                          icon: Icons.audiotrack,
                          title: 'Play or share WAV output',
                          body:
                              'The app writes generated speech to a local WAV file before playback or sharing.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AboutSection(
                    title: 'Current status',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusLine(
                          label: 'Selected voice',
                          value: state.selectedModel?.voice.displayName ??
                              'No voice selected yet',
                        ),
                        const SizedBox(height: 10),
                        _StatusLine(
                          label: 'Model readiness',
                          value: !hasReadyModel
                              ? 'Install a model to begin'
                              : 'Ready for offline generation',
                        ),
                        const SizedBox(height: 10),
                        _StatusLine(
                          label: 'Latest audio',
                          value: state.hasAudio
                              ? 'Generated audio is available'
                              : 'No generated audio yet',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReadyModel =
        state.selectedModel?.status == ModelStatus.ready &&
        state.selectedModel?.modelDir != null;
    final subtitle = !hasReadyModel
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

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
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