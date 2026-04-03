import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import '../state/app_state.dart';

class ModelStatusCard extends StatelessWidget {
  const ModelStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.isDownloading) {
          return _DownloadingCard(state: state);
        }

        final readyModels = state.readyModels;
        final installable = state.installableModels;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      readyModels.isEmpty ? Icons.download : Icons.check_circle,
                      color: readyModels.isEmpty
                          ? Theme.of(context).colorScheme.primary
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        readyModels.isEmpty
                            ? 'No model installed yet'
                            : '${readyModels.length} model${readyModels.length == 1 ? '' : 's'} ready',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: state.refreshModels,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh model status',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  readyModels.isEmpty
                      ? 'Download a development voice into app-private storage to unlock local speech generation.'
                      : 'Models are stored privately under ${state.modelsDirectory ?? 'the app support directory'}.',
                ),
                if (installable.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: installable.map((model) {
                      final label = model.status == ModelStatus.incomplete
                          ? 'Repair ${model.voice.displayName}'
                          : 'Install ${model.voice.displayName}';
                      return FilledButton.tonal(
                        onPressed: () => state.downloadModel(model.voice),
                        child: Text(label),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DownloadingCard extends StatelessWidget {
  const _DownloadingCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Installing model...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: state.downloadProgress > 0 ? state.downloadProgress : null,
            ),
            const SizedBox(height: 8),
            Text('${(state.downloadProgress * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}