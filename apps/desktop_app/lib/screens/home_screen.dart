import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../services/audio_service.dart';
import '../widgets/model_status_banner.dart';
import '../widgets/text_input_panel.dart';
import '../widgets/settings_panel.dart';
import 'voice_lab_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        centerTitle: false,
        actions: [
          Consumer<AppState>(
            builder: (context, state, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.science_outlined, size: 18),
                    Transform.scale(
                      scale: 0.72,
                      child: Switch(
                        value: state.isAdvancedLabEnabled,
                        onChanged: state.setAdvancedLabEnabled,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.isLoadingModels) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.isAdvancedLabEnabled) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildBasicPane(context, state),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildBasicPane(context, state),
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: VoiceLabPanel(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBasicPane(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModelStatusBanner(),
        const SizedBox(height: 16),
        const TextInputPanel(),
        const SizedBox(height: 16),
        const SettingsPanel(),
        const SizedBox(height: 16),
        _buildGenerateButton(context, state),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(context, state.errorMessage!),
        ],
        const SizedBox(height: 16),
        TaskListPanel(
          playbackInfo: TaskPlaybackInfo(
            playingTaskId: state.playingTaskId,
            isPlaying: state.playbackState == PlaybackState.playing,
            activeTaskId: state.activeTaskId,
            position: state.playbackPosition,
            duration: state.playbackDuration,
          ),
          onPlay: (path) => state.playTaskAudio(path),
          onStop: () => state.stopPlayback(),
          onSeek: (position) => state.seekPlayback(position),
          onSave: (path) => state.saveTaskAudio(path),
          onCancelTask: state.cancelManagedTask,
          onDismissTask: state.dismissManagedTask,
        ),
      ],
    );
  }

  Widget _buildGenerateButton(BuildContext context, AppState state) {
    final hasActiveSynthesis = state.taskManager.hasActiveSynthesisTasks;
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: state.canGenerate ? () => state.generate() : null,
        icon: Icon(
          hasActiveSynthesis ? Icons.add_task : Icons.record_voice_over,
        ),
        label: Text(
          hasActiveSynthesis ? 'Queue speech task' : 'Generate Speech',
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
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
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
