import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import '../state/app_state.dart';

/// Shows a compact readiness summary now that full model management lives on
/// the dedicated Models screen.
class ModelStatusBanner extends StatelessWidget {
  const ModelStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.isDownloading) {
          return _downloadingBanner(context, state);
        }

        return _summaryBanner(context, state);
      },
    );
  }

  Widget _summaryBanner(BuildContext context, AppState state) {
    final readyModels = state.readyModels;
    final hasReadyModels = readyModels.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedVoice = state.selectedModel?.voice.displayName;

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
                  ? 'Selected voice: ${selectedVoice ?? 'None'}. Open Models from the navigation menu to install or repair other voices.'
                  : 'Open Models from the navigation menu to download a voice model before generating speech.',
              style: TextStyle(
                color: hasReadyModels ? null : colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadingBanner(BuildContext context, AppState state) {
    final progress = state.currentInstallProgress;
    final statusText = progress?.stage.label ?? 'Downloading';
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
                  '$statusText model...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress?.progress,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 4),
            Text(
              progress?.totalBytes != null
                  ? '${_formatMegabytes(progress?.downloadedBytes ?? 0)} / ${_formatMegabytes(progress!.totalBytes!)}'
                  : progress?.progress != null
                  ? '${(progress!.progress! * 100).toStringAsFixed(0)}%'
                  : statusText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMegabytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }
}
