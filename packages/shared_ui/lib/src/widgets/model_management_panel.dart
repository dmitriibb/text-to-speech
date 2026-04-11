import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

class ModelManagementPanel extends StatelessWidget {
  const ModelManagementPanel({
    super.key,
    required this.models,
    required this.selectedModelId,
    required this.isDownloading,
    required this.currentInstallProgress,
    required this.canManageModels,
    required this.storageDescription,
    required this.onRefresh,
    required this.onInstall,
  });

  final List<InstalledModel> models;
  final String? selectedModelId;
  final bool isDownloading;
  final ModelInstallProgress? currentInstallProgress;
  final bool canManageModels;
  final String storageDescription;
  final Future<void> Function() onRefresh;
  final Future<void> Function(VoiceModel voice) onInstall;

  @override
  Widget build(BuildContext context) {
    final readyModels = models
        .where((model) => model.status == ModelStatus.ready)
        .toList(growable: false);
    final installableModels = models
        .where((model) => model.status != ModelStatus.ready)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(
          readyCount: readyModels.length,
          totalCount: models.length,
          selectedModelId: selectedModelId,
          models: models,
          storageDescription: storageDescription,
          canManageModels: canManageModels,
          onRefresh: onRefresh,
        ),
        if (isDownloading) ...[
          const SizedBox(height: 16),
          _DownloadingCard(progress: currentInstallProgress),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available models',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (models.isEmpty)
                  Text(
                    'No catalog entries are available.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ..._buildModelRows(
                    context,
                    models,
                    installableCount: installableModels.length,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildModelRows(
    BuildContext context,
    List<InstalledModel> models, {
    required int installableCount,
  }) {
    final widgets = <Widget>[];

    for (var index = 0; index < models.length; index++) {
      final model = models[index];
      final isSelected = model.voice.id == selectedModelId;
      final actionLabel = _actionLabel(model);

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: index == models.length - 1 ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          model.voice.displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        _StatusChip(
                          label: _statusLabel(model.status),
                          color: _statusColor(context, model.status),
                        ),
                        if (isSelected) const _StatusChip(label: 'Selected'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _detailsLine(model),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: canManageModels
                      ? () => onInstall(model.voice)
                      : null,
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      );

      if (index != models.length - 1) {
        widgets.add(const Divider(height: 1));
        widgets.add(const SizedBox(height: 12));
      }
    }

    if (installableCount == 0) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Text(
          'All approved models in the catalog are already installed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return widgets;
  }

  String? _actionLabel(InstalledModel model) {
    switch (model.status) {
      case ModelStatus.notInstalled:
        return 'Install';
      case ModelStatus.incomplete:
        return 'Repair';
      case ModelStatus.downloading:
      case ModelStatus.ready:
        return null;
    }
  }

  String _statusLabel(ModelStatus status) {
    switch (status) {
      case ModelStatus.notInstalled:
        return 'Not installed';
      case ModelStatus.downloading:
        return 'Downloading';
      case ModelStatus.ready:
        return 'Ready';
      case ModelStatus.incomplete:
        return 'Needs repair';
    }
  }

  Color? _statusColor(BuildContext context, ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return Colors.green.shade700;
      case ModelStatus.incomplete:
        return Theme.of(context).colorScheme.error;
      case ModelStatus.downloading:
        return Theme.of(context).colorScheme.primary;
      case ModelStatus.notInstalled:
        return null;
    }
  }

  String _detailsLine(InstalledModel model) {
    final family = model.voice.family.toUpperCase();
    final extras = <String>[
      family,
      if (model.voice.speakers.isNotEmpty)
        '${model.voice.speakers.length} speakers',
      if (model.voice.voiceCloning) 'voice cloning',
    ];

    return extras.join(' • ');
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.readyCount,
    required this.totalCount,
    required this.selectedModelId,
    required this.models,
    required this.storageDescription,
    required this.canManageModels,
    required this.onRefresh,
  });

  final int readyCount;
  final int totalCount;
  final String? selectedModelId;
  final List<InstalledModel> models;
  final String storageDescription;
  final bool canManageModels;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedModel = models
        .where((model) => model.voice.id == selectedModelId)
        .firstOrNull;
    final hasReadyModels = readyCount > 0;

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
                  hasReadyModels ? Icons.check_circle : Icons.download,
                  color: hasReadyModels
                      ? Colors.green.shade700
                      : colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasReadyModels
                        ? '$readyCount of $totalCount model${totalCount == 1 ? '' : 's'} ready'
                        : 'No model installed yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: hasReadyModels
                          ? null
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canManageModels ? onRefresh : null,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh model status',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectedModel == null
                  ? 'Install one approved model to unlock local generation. $storageDescription'
                  : 'Selected voice: ${selectedModel.voice.displayName}. $storageDescription',
              style: TextStyle(
                color: hasReadyModels ? null : colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadingCard extends StatelessWidget {
  const _DownloadingCard({required this.progress});

  final ModelInstallProgress? progress;

  @override
  Widget build(BuildContext context) {
    final statusText = progress?.stage.label ?? 'Downloading';
    final totalBytes = progress?.totalBytes;
    final progressValue = progress?.progress;

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
              totalBytes != null
                  ? '${_formatMegabytes(progress!.downloadedBytes)} / ${_formatMegabytes(totalBytes)}'
                  : progressValue != null
                  ? '${(progressValue * 100).toStringAsFixed(0)}%'
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      side: BorderSide(
        color: color ?? Theme.of(context).colorScheme.outlineVariant,
      ),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
