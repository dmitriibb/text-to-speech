import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../state/app_state.dart';

/// Audio playback controls and WAV export action.
class PlaybackPanel extends StatelessWidget {
  const PlaybackPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildPlayStopButton(context, state),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    state.playbackState == PlaybackState.playing
                        ? 'Playing...'
                        : 'Ready to play',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 16),
                _buildSaveButton(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayStopButton(BuildContext context, AppState state) {
    final isPlaying = state.playbackState == PlaybackState.playing;

    return IconButton.filled(
      iconSize: 32,
      onPressed: () {
        if (isPlaying) {
          state.stopPlayback();
        } else {
          state.play();
        }
      },
      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
      tooltip: isPlaying ? 'Stop' : 'Play',
    );
  }

  Widget _buildSaveButton(BuildContext context, AppState state) {
    return FilledButton.tonal(
      onPressed: () => _saveWav(context, state),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.save_alt, size: 18),
          SizedBox(width: 6),
          Text('Save WAV'),
        ],
      ),
    );
  }

  Future<void> _saveWav(BuildContext context, AppState state) async {
    String? savePath;
    if (Platform.isLinux) {
      savePath = await _zenitySaveDialog();
    } else {
      final home = Platform.environment['USERPROFILE'] ?? '.';
      savePath = '$home\\Documents\\speech.wav';
    }

    if (savePath == null) return;

    // Ensure .wav extension.
    if (!savePath.toLowerCase().endsWith('.wav')) {
      savePath = '$savePath.wav';
    }

    if (!context.mounted) return;

    final ok = await state.exportWav(savePath);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved to $savePath' : 'Save failed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Uses zenity for a native GTK save dialog on Linux.
  Future<String?> _zenitySaveDialog() async {
    try {
      final result = await Process.run('zenity', [
        '--file-selection',
        '--save',
        '--confirm-overwrite',
        '--title=Save WAV file',
        '--filename=speech.wav',
        '--file-filter=WAV files (*.wav) | *.wav',
      ]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {
      // zenity not available.
    }
    return null;
  }
}
