import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'about_screen.dart';
import '../state/app_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/model_status_card.dart';
import '../widgets/playback_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/text_input_panel.dart';

enum _HomeMenuAction { about }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _HomeMenuAction.about:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.about,
                child: Text('About'),
              ),
            ],
          ),
        ],
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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