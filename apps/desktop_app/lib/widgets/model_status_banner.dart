import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import '../state/app_state.dart';

/// Shows model install status and keeps the full desktop catalog discoverable.
class ModelStatusBanner extends StatelessWidget {
  const ModelStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.isDownloading) {
          return _downloadingBanner(context, state);
        }

        return _modelCatalogBanner(context, state);
      },
    );
  }

  Widget _modelCatalogBanner(BuildContext context, AppState state) {
    final readyModels = state.readyModels;
    final installableModels = state.installableModels;
    final hasReadyModels = readyModels.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: hasReadyModels ? null : colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasReadyModels ? Icons.check_circle : Icons.info_outline,
                  color: hasReadyModels
                      ? Colors.green.shade700
                      : colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasReadyModels
                        ? '${readyModels.length} model${readyModels.length == 1 ? '' : 's'} ready'
                        : 'No voice model installed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: hasReadyModels
                          ? null
                          : colorScheme.onSecondaryContainer,
                    ),
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
              hasReadyModels
                  ? 'Installed models appear in the Voice selector. Additional approved desktop models can still be installed below.'
                  : 'Download a voice model to start generating speech.',
              style: TextStyle(
                color: hasReadyModels ? null : colorScheme.onSecondaryContainer,
              ),
            ),
            if (readyModels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: readyModels
                    .map((model) => Chip(label: Text(model.voice.displayName)))
                    .toList(),
              ),
            ],
            if (installableModels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Available to install',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: installableModels.map((m) {
                  final label = m.status == ModelStatus.incomplete
                      ? 'Repair ${m.voice.displayName}'
                      : 'Install ${m.voice.displayName}';
                  return FilledButton.tonal(
                    onPressed: () => state.downloadModel(m.voice),
                    child: Text(label),
                  );
                }).toList(),
              ),
            ] else if (hasReadyModels) ...[
              const SizedBox(height: 12),
              Text(
                'All approved desktop models from the catalog are already installed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Downloading model...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.downloadProgress > 0 ? state.downloadProgress : null,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
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
