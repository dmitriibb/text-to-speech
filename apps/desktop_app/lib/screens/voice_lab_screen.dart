import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../models/cloned_voice.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../state/voice_lab_state.dart';

class VoiceLabScreen extends StatefulWidget {
  const VoiceLabScreen({super.key});

  @override
  State<VoiceLabScreen> createState() => _VoiceLabScreenState();
}

class _VoiceLabScreenState extends State<VoiceLabScreen> {
  late final VoiceLabState _state;
  final _textController = TextEditingController();
  final double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _state = VoiceLabState(appState: appState);
    _state.initialize();
  }

  @override
  void dispose() {
    _textController.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: Scaffold(
        appBar: AppBar(title: const Text('Voice Lab'), centerTitle: false),
        body: Consumer<VoiceLabState>(
          builder: (context, state, _) {
            if (state.isLoading) {
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
                      // Pocket TTS model status
                      _buildModelStatus(context, state),

                      const SizedBox(height: 24),

                      // Import voice button
                      _buildImportSection(context, state),

                      const SizedBox(height: 24),

                      // Voice library
                      _buildVoiceLibrary(context, state),

                      // Error banner
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorBanner(context, state.errorMessage!),
                      ],

                      // Task list for cloned speech output
                      const SizedBox(height: 16),
                      Consumer<AppState>(
                        builder: (context, appState, _) {
                          return TaskListPanel(
                            playbackInfo: TaskPlaybackInfo(
                              playingTaskId: appState.playingTaskId,
                              isPlaying:
                                  appState.playbackState ==
                                  PlaybackState.playing,
                              activeTaskId: appState.activeTaskId,
                              position: appState.playbackPosition,
                              duration: appState.playbackDuration,
                            ),
                            onPlay: (path) => appState.playTaskAudio(path),
                            onStop: () => appState.stopPlayback(),
                            onSeek: (position) =>
                                appState.seekPlayback(position),
                            onSave: (path) => appState.saveTaskAudio(path),
                            onCancelTask: appState.cancelManagedTask,
                            onDismissTask: appState.dismissManagedTask,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModelStatus(BuildContext context, VoiceLabState state) {
    if (state.hasPocketModel) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pocket TTS model is ready for voice cloning.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pocket TTS model not installed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Install the Pocket TTS model from the model catalog on the main screen to enable voice cloning.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context, VoiceLabState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Voice Sample',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Provide a short WAV audio clip (10–30 seconds) of the voice you want to clone.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _showImportDialog(context, state),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import WAV File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceLibrary(BuildContext context, VoiceLabState state) {
    if (state.voices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No cloned voices yet. Import a voice sample to get started.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voice Library', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...state.voices.map((voice) => _buildVoiceCard(context, state, voice)),
      ],
    );
  }

  Widget _buildVoiceCard(
    BuildContext context,
    VoiceLabState state,
    ClonedVoice voice,
  ) {
    final isPreviewing =
        state.previewingVoiceId == voice.id && state.isPreviewPlaying;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Created ${_formatDate(voice.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // Preview button
                IconButton(
                  onPressed: isPreviewing
                      ? () => state.stopPreview()
                      : () => state.previewVoice(voice),
                  icon: Icon(isPreviewing ? Icons.stop : Icons.play_arrow),
                  tooltip: isPreviewing ? 'Stop preview' : 'Preview reference',
                ),
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(context, state, voice),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete voice',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Synthesis controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Enter text to speak with this voice...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: state.hasPocketModel
                      ? () => state.generateWithClonedVoice(
                          voice: voice,
                          text: _textController.text,
                          speed: _speed,
                        )
                      : null,
                  icon: const Icon(Icons.record_voice_over, size: 18),
                  label: const Text('Clone'),
                ),
              ],
            ),
          ],
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
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }

  Future<void> _showImportDialog(
    BuildContext context,
    VoiceLabState state,
  ) async {
    final nameController = TextEditingController();
    final pathController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Voice Sample'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Voice Name',
                  hintText: 'e.g., "My Voice", "Narrator"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'WAV File Path',
                  hintText: '/path/to/reference.wav',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use a 10–30 second mono WAV clip of the voice you want to clone.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final path = pathController.text.trim();

      if (name.isEmpty || path.isEmpty) {
        return;
      }

      if (!File(path).existsSync()) {
        state.setError('File not found: $path');
        return;
      }

      await state.addVoice(name: name, audioPath: path);
    }

    nameController.dispose();
    pathController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    VoiceLabState state,
    ClonedVoice voice,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voice'),
        content: Text('Remove "${voice.name}" from the voice library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await state.removeVoice(voice.id);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
