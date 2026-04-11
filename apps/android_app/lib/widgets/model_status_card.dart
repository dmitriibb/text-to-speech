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
        final selectedVoice = state.selectedModel?.voice.displayName;

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
                      onPressed: state.canManageModels
                          ? state.refreshModels
                          : null,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh model status',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  readyModels.isEmpty
                      ? 'Open Models from the navigation menu to install a voice into app-private storage.'
                      : 'Selected voice: ${selectedVoice ?? 'None'}. Manage installs from the Models screen.',
                ),
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
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  '$statusText model...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: progress?.progress),
            const SizedBox(height: 8),
            Text(
              progress?.totalBytes != null
                  ? '${_formatMegabytes(progress!.downloadedBytes)} / ${_formatMegabytes(progress.totalBytes!)}'
                  : progress?.progress != null
                  ? '${(progress!.progress! * 100).toStringAsFixed(0)}%'
                  : statusText,
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
