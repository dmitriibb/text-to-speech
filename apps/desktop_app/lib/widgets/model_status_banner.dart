import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/voice_model.dart';
import '../state/app_state.dart';

/// Shows model install status and download action when no model is ready.
class ModelStatusBanner extends StatelessWidget {
  const ModelStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.isDownloading) {
          return _downloadingBanner(context, state);
        }

        if (state.readyModels.isNotEmpty) {
          return const SizedBox.shrink();
        }

        return _noModelBanner(context, state);
      },
    );
  }

  Widget _noModelBanner(BuildContext context, AppState state) {
    final downloadable = state.downloadableModels;

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'No voice model installed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Download a voice model to start generating speech.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            if (downloadable.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: downloadable.map((m) {
                  return FilledButton.tonal(
                    onPressed: () => state.downloadModel(m.voice),
                    child: Text('Download ${m.voice.displayName}'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloadingBanner(BuildContext context, AppState state) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Downloading model...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.downloadProgress > 0 ? state.downloadProgress : null,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 4),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
