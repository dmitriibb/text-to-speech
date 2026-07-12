import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/settings_panel.dart';
import '../widgets/text_input_panel.dart';
import 'dialog_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';
import 'backend_models_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.home,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Text to Speech'), centerTitle: false),
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
                child: _buildBasicPane(context, state),
              ),
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
          onPausePlayback: () => state.pausePlayback(),
          onSeek: (position) => state.seekPlayback(position),
          onSave: (path) => state.saveTaskAudio(path),
          onCancelTask: state.cancelManagedTask,
          onDismissTask: state.dismissManagedTask,
          onClearAllTasks: state.clearAllManagedTasks,
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

  void _navigateToDestination(
    BuildContext context,
    AppDestination destination,
  ) {
    Navigator.of(context).pop();

    switch (destination) {
      case AppDestination.home:
        break;
      case AppDestination.liveTts:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const LiveTtsScreen()),
        );
      case AppDestination.dialog:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const DialogScreen()),
        );
      case AppDestination.models:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const ModelsScreen()),
        );
      case AppDestination.voiceLab:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => const BackendModelsScreen(),
          ),
        );
    }
  }
}
