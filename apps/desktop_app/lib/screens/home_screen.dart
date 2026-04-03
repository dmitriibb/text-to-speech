import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/model_status_banner.dart';
import '../widgets/text_input_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/playback_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        centerTitle: false,
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.isLoadingModels) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Model status banner (shows if no model ready).
                    const ModelStatusBanner(),

                    const SizedBox(height: 16),

                    // Text input.
                    const TextInputPanel(),

                    const SizedBox(height: 16),

                    // Voice and speed settings.
                    const SettingsPanel(),

                    const SizedBox(height: 16),

                    // Generate button.
                    _buildGenerateButton(context, state),

                    // Error message.
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorBanner(context, state.errorMessage!),
                    ],

                    // Playback panel.
                    if (state.hasAudio &&
                        state.synthesisStatus == SynthesisStatus.done) ...[
                      const SizedBox(height: 24),
                      const PlaybackPanel(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenerateButton(BuildContext context, AppState state) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: state.canGenerate ? () => state.generate() : null,
        icon: state.synthesisStatus == SynthesisStatus.generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.record_voice_over),
        label: Text(
          state.synthesisStatus == SynthesisStatus.generating
              ? 'Generating...'
              : 'Generate Speech',
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
