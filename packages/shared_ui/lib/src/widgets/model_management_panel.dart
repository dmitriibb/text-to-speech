import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

class ModelManagementPanel extends StatelessWidget {
  const ModelManagementPanel({
    super.key,
    required this.models,
    required this.isDownloading,
    required this.currentInstallProgress,
    required this.canManageModels,
    required this.onRefresh,
    required this.onInstall,
    required this.onDelete,
  });

  final List<InstalledModel> models;
  final bool isDownloading;
  final ModelInstallProgress? currentInstallProgress;
  final bool canManageModels;
  final Future<void> Function() onRefresh;
  final Future<void> Function(VoiceModel voice) onInstall;
  final Future<void> Function(VoiceModel voice) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Available models',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: canManageModels ? onRefresh : null,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh model status',
            ),
          ],
        ),
        if (isDownloading) ...[
          const SizedBox(height: 12),
          _DownloadingCard(progress: currentInstallProgress),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                const _HeaderRow(),
                const Divider(height: 1),
                if (models.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No catalog entries are available.'),
                    ),
                  )
                else
                  ..._buildModelTiles(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildModelTiles(BuildContext context) {
    final widgets = <Widget>[];

    for (var index = 0; index < models.length; index++) {
      final model = models[index];
      widgets.add(
        _ModelTile(
          model: model,
          canManageModels: canManageModels,
          onInstall: onInstall,
          onDelete: onDelete,
        ),
      );
      if (index != models.length - 1) {
        widgets.add(const Divider(height: 1));
      }
    }

    return widgets;
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(flex: 6, child: Text('Model', style: style)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Size', style: style),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Status', style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.canManageModels,
    required this.onInstall,
    required this.onDelete,
  });

  final InstalledModel model;
  final bool canManageModels;
  final Future<void> Function(VoiceModel voice) onInstall;
  final Future<void> Function(VoiceModel voice) onDelete;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>('model-${model.voice.id}'),
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              flex: 6,
              child: Text(
                model.voice.displayName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(_sizeLabel(model.voice.sizeMb)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _statusLabel(model.status),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _statusColor(context, model.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        children: [
          _DetailLine(label: 'Size', value: _sizeLabel(model.voice.sizeMb)),
          _DetailLine(
            label: 'Model family',
            value: _familyLabel(model.voice.family),
          ),
          _DetailLine(
            label: 'Engine',
            value: _runtimeLabel(model.voice.runtime),
          ),
          _DetailLine(
            label: 'Supported languages',
            value: model.voice.supportedLanguages.isEmpty
                ? 'Unknown'
                : model.voice.supportedLanguages.join(', '),
          ),
          _DetailLine(
            label: 'Description',
            value: model.voice.description.isEmpty
                ? 'Unknown'
                : model.voice.description,
          ),
          if (model.status != ModelStatus.notInstalled &&
              model.modelDir != null)
            _DetailLine(label: 'Installed at', value: model.modelDir!),
          const SizedBox(height: 12),
          Row(
            children: [
              if (model.status == ModelStatus.notInstalled ||
                  model.status == ModelStatus.incomplete)
                FilledButton.tonal(
                  onPressed: canManageModels
                      ? () => onInstall(model.voice)
                      : null,
                  child: Text(
                    model.status == ModelStatus.incomplete
                        ? 'Repair model'
                        : 'Install model',
                  ),
                ),
              if (model.status != ModelStatus.notInstalled &&
                  model.modelDir != null) ...[
                OutlinedButton.icon(
                  onPressed: canManageModels
                      ? () => onDelete(model.voice)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete downloaded files'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _sizeLabel(double sizeMb) {
    if (sizeMb <= 0) {
      return 'Unknown';
    }
    return '${sizeMb.toStringAsFixed(sizeMb.truncateToDouble() == sizeMb ? 0 : 1)} MB';
  }

  static String _statusLabel(ModelStatus status) {
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

  static Color _statusColor(BuildContext context, ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return Colors.green.shade700;
      case ModelStatus.incomplete:
        return Theme.of(context).colorScheme.error;
      case ModelStatus.downloading:
        return Theme.of(context).colorScheme.primary;
      case ModelStatus.notInstalled:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  static String _familyLabel(String family) {
    switch (family) {
      case 'vits':
        return 'VITS';
      case 'kokoro':
        return 'Kokoro';
      case 'pocket':
        return 'Pocket TTS';
      default:
        return family;
    }
  }

  static String _runtimeLabel(String runtime) {
    switch (runtime) {
      case 'sherpa-onnx':
        return 'Sherpa ONNX';
      default:
        return runtime;
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
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
