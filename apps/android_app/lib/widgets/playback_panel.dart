import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../state/app_state.dart';

class PlaybackPanel extends StatelessWidget {
  const PlaybackPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isPlaying = state.playbackState == PlaybackState.playing;
        final filePath = state.generatedWavPath;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated audio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                if (filePath != null)
                  Text(
                    p.basename(filePath),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: isPlaying ? state.stopPlayback : state.play,
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(isPlaying ? 'Stop' : 'Play'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _share(context, state),
                      icon: const Icon(Icons.share),
                      label: const Text('Share WAV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _share(BuildContext context, AppState state) async {
    final ok = await state.shareGeneratedAudio();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Share sheet opened' : 'Share failed'),
      ),
    );
  }
}