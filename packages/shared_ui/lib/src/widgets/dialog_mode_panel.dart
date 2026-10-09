import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

import 'model_selector.dart';
import 'audio_playback_controls.dart';

class DialogModePanel extends StatelessWidget {
  const DialogModePanel({
    super.key,
    required this.lines,
    required this.readyModels,
    required this.speakerSettings,
    required this.isGenerating,
    required this.isSequencePlaying,
    required this.activeLineId,
    required this.errorMessage,
    required this.onPasteFromClipboard,
    required this.onGenerate,
    required this.onPlayPauseSequence,
    required this.onStopSequence,
    required this.onPlayLine,
    required this.onRemoveLine,
    required this.onModelSelected,
    required this.onSettingsChanged,
    this.importIssues = const [],
    this.workspace,
    this.onRetryLine,
    this.onRenderConversation,
    this.onPreviewConversation,
    this.onExportConversation,
    this.extensionBuilderForSpeaker,
    this.masterIsPlaying = false,
    this.masterPosition = Duration.zero,
    this.masterDuration,
    this.onSeekMaster,
  });

  final List<DialogLineItem> lines;
  final List<InstalledModel> readyModels;
  final Map<String, DialogSpeakerSettings> speakerSettings;
  final bool isGenerating;
  final bool isSequencePlaying;
  final String? activeLineId;
  final String? errorMessage;
  final Future<void> Function() onPasteFromClipboard;
  final Future<void> Function() onGenerate;
  final Future<void> Function() onPlayPauseSequence;
  final Future<void> Function() onStopSequence;
  final Future<void> Function(DialogLineItem line) onPlayLine;
  final Future<void> Function(DialogLineItem line) onRemoveLine;
  final void Function(String speakerName, InstalledModel model) onModelSelected;
  final void Function(String speakerName, ModelSynthesisSettings settings)
  onSettingsChanged;
  final List<DialogImportIssue> importIssues;
  final DialogWorkspace? workspace;
  final bool masterIsPlaying;
  final Duration masterPosition;
  final Duration? masterDuration;
  final ValueChanged<Duration>? onSeekMaster;
  final Future<void> Function(DialogLineItem)? onRetryLine;
  final Future<void> Function()? onRenderConversation,
      onPreviewConversation,
      onExportConversation;
  final ModelSettingsExtensionBuilder Function(String)?
  extensionBuilderForSpeaker;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (workspace != null) _ProjectControls(workspace: workspace!),
          Center(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: onPasteFromClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste from buffer'),
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            _DialogErrorBanner(message: errorMessage!),
          ],
          if (importIssues.isNotEmpty)
            _DialogImportIssues(issues: importIssues),
        ],
      );
    }

    final speakers = _orderedSpeakerNames();
    final hasPlayableLines = lines.any((line) => line.hasPlayableAudio);
    final hasTextLines = lines.any((line) => line.hasText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (workspace != null) ...[
          _ProjectControls(workspace: workspace!),
          const SizedBox(height: 12),
        ],
        if (importIssues.isNotEmpty) ...[
          _DialogImportIssues(issues: importIssues),
          const SizedBox(height: 12),
        ],
        _SpeakerSettingsList(
          speakers: speakers,
          readyModels: readyModels,
          speakerSettings: speakerSettings,
          onModelSelected: onModelSelected,
          onSettingsChanged: onSettingsChanged,
          extensionBuilderForSpeaker: extensionBuilderForSpeaker,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: isGenerating ? null : onPasteFromClipboard,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste from buffer'),
            ),
            FilledButton.icon(
              onPressed: hasTextLines && !isGenerating ? onGenerate : null,
              icon: Icon(
                isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
              ),
              label: Text(
                isGenerating ? 'Generating' : 'Generate missing / changed',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: hasPlayableLines ? onPlayPauseSequence : null,
              icon: Icon(isSequencePlaying ? Icons.pause : Icons.play_arrow),
              label: Text(isSequencePlaying ? 'Pause' : 'Play'),
            ),
            OutlinedButton.icon(
              onPressed: activeLineId != null ? onStopSequence : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
        if (workspace != null) ...[
          const SizedBox(height: 12),
          _ConversationControls(
            workspace: workspace!,
            onRender: onRenderConversation,
            onPreview: onPreviewConversation,
            onExport: onExportConversation,
          ),
        ],
        if (workspace?.masterIsCurrent == true &&
            onPreviewConversation != null) ...[
          const SizedBox(height: 12),
          AudioPlaybackControls(
            isPlaying: masterIsPlaying,
            position: masterPosition,
            duration: masterDuration,
            onTogglePlayback: onPreviewConversation!,
            onSeek: onSeekMaster,
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _DialogErrorBanner(message: errorMessage!),
        ],
        const SizedBox(height: 16),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DialogLineCard(
              line: line,
              isActive: activeLineId == line.id,
              isPlaying: activeLineId == line.id && isSequencePlaying,
              onPlay: () => onPlayLine(line),
              onRemove: () => onRemoveLine(line),
              onEdit: workspace == null
                  ? null
                  : () => _editTurn(context, workspace!, line),
              onRetry: onRetryLine == null || isGenerating
                  ? null
                  : () => onRetryLine!(line),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _orderedSpeakerNames() {
    final names = <String>[];
    final seen = <String>{};
    for (final line in lines) {
      if (seen.add(line.speakerName)) {
        names.add(line.speakerName);
      }
    }
    return names;
  }
}

class _DialogImportIssues extends StatelessWidget {
  const _DialogImportIssues({required this.issues});

  final List<DialogImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.warning_amber),
        title: Text(
          'Skipped ${issues.length} transcript ${issues.length == 1 ? 'row' : 'rows'}',
        ),
        subtitle: const Text('Review these rows before generating.'),
        children: [
          for (final issue in issues)
            ListTile(
              title: Text('Line ${issue.sourceLineNumber}: ${issue.message}'),
              subtitle: SelectableText(issue.sourceText),
            ),
        ],
      ),
    );
  }
}

class _SpeakerSettingsList extends StatelessWidget {
  const _SpeakerSettingsList({
    required this.speakers,
    required this.readyModels,
    required this.speakerSettings,
    required this.onModelSelected,
    required this.onSettingsChanged,
    this.extensionBuilderForSpeaker,
  });

  final List<String> speakers;
  final List<InstalledModel> readyModels;
  final Map<String, DialogSpeakerSettings> speakerSettings;
  final void Function(String speakerName, InstalledModel model) onModelSelected;
  final void Function(String speakerName, ModelSynthesisSettings settings)
  onSettingsChanged;

  final ModelSettingsExtensionBuilder Function(String)?
  extensionBuilderForSpeaker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final speakerName in speakers) ...[
          _SpeakerSettingsRow(
            speakerName: speakerName,
            readyModels: readyModels,
            settings: speakerSettings[speakerName],
            onModelSelected: onModelSelected,
            onSettingsChanged: onSettingsChanged,
            extensionBuilderForSpeaker: extensionBuilderForSpeaker,
          ),
          if (speakerName != speakers.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SpeakerSettingsRow extends StatelessWidget {
  const _SpeakerSettingsRow({
    required this.speakerName,
    required this.readyModels,
    required this.settings,
    required this.onModelSelected,
    required this.onSettingsChanged,
    this.extensionBuilderForSpeaker,
  });

  final String speakerName;
  final List<InstalledModel> readyModels;
  final DialogSpeakerSettings? settings;
  final void Function(String speakerName, InstalledModel model) onModelSelected;
  final void Function(String speakerName, ModelSynthesisSettings settings)
  onSettingsChanged;

  final ModelSettingsExtensionBuilder Function(String)?
  extensionBuilderForSpeaker;

  @override
  Widget build(BuildContext context) {
    final selectedModel = _selectedModel();
    final modelSettings =
        settings?.synthesisSettings ??
        (selectedModel == null
            ? const ModelSynthesisSettings()
            : ModelSynthesisSettings.defaultsFor(selectedModel.voice));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 160, child: _SpeakerNameLabel(name: speakerName)),
        const SizedBox(width: 12),
        Expanded(
          child: ModelSelector(
            readyModels: readyModels,
            extensionBuilder: extensionBuilderForSpeaker?.call(speakerName),
            supportsSpeed: selectedModel?.voice.runtime != 'voxcpm2',

            selectedModel: selectedModel,
            settings: modelSettings,
            enabled: readyModels.isNotEmpty,
            onModelSelected: (model) => onModelSelected(speakerName, model),
            onSettingsChanged: (next) => onSettingsChanged(speakerName, next),
          ),
        ),
      ],
    );
  }

  InstalledModel? _selectedModel() {
    final modelId = settings?.modelId;
    if (modelId == null) {
      return null;
    }
    for (final model in readyModels) {
      if (model.voice.id == modelId) {
        return model;
      }
    }
    return null;
  }
}

class _SpeakerNameLabel extends StatelessWidget {
  const _SpeakerNameLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DialogLineCard extends StatelessWidget {
  const _DialogLineCard({
    required this.line,
    required this.isActive,
    required this.isPlaying,
    required this.onPlay,
    required this.onRemove,
    this.onEdit,
    this.onRetry,
  });
  final DialogLineItem line;
  final bool isActive, isPlaying;
  final VoidCallback onPlay, onRemove;
  final VoidCallback? onEdit, onRetry;
  @override
  Widget build(BuildContext context) => Card(
    elevation: isActive ? 2 : 0,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.speakerName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (!line.included) const Text('Excluded'),
              _LineStatusIcon(status: line.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            line.hasText ? line.effectiveText : 'Text removed',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (line.errorMessage != null)
            Text(
              line.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            spacing: 4,
            children: [
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit text / timing / inclusion',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              IconButton(
                tooltip: 'Retry this line',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Remove line',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton.filledTonal(
                tooltip: isPlaying ? 'Pause line' : 'Play line',
                onPressed: line.hasPlayableAudio ? onPlay : null,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LineStatusIcon extends StatelessWidget {
  const _LineStatusIcon({required this.status});

  final DialogLineStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (status) {
      DialogLineStatus.ready => (
        'Ready',
        Icons.check_circle_outline,
        colorScheme.primary,
      ),
      DialogLineStatus.failed => (
        'Failed',
        Icons.error_outline,
        colorScheme.error,
      ),
      DialogLineStatus.queued => (
        'Queued',
        Icons.schedule,
        colorScheme.onSurfaceVariant,
      ),
      DialogLineStatus.generating => (
        'Generating',
        Icons.hourglass_top,
        colorScheme.onSurfaceVariant,
      ),
      DialogLineStatus.idle => (
        'Not ready',
        Icons.radio_button_unchecked,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Tooltip(
      message: label,
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _DialogErrorBanner extends StatelessWidget {
  const _DialogErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectControls extends StatelessWidget {
  const _ProjectControls({required this.workspace});
  final DialogWorkspace workspace;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: workspace.isGenerating || workspace.isRendering
            ? null
            : workspace.save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save project'),
      ),
      OutlinedButton.icon(
        onPressed: workspace.isGenerating || workspace.isRendering
            ? null
            : workspace.load,
        icon: const Icon(Icons.folder_open),
        label: const Text('Reload saved project'),
      ),
      OutlinedButton.icon(
        onPressed: () => _editTiming(context, workspace),
        icon: const Icon(Icons.timer_outlined),
        label: Text('Default pause: ${workspace.defaultPauseMs} ms'),
      ),
    ],
  );
}

class _ConversationControls extends StatelessWidget {
  const _ConversationControls({
    required this.workspace,
    this.onRender,
    this.onPreview,
    this.onExport,
  });
  final DialogWorkspace workspace;
  final Future<void> Function()? onRender, onPreview, onExport;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: workspace.isRendering || workspace.isGenerating
                ? null
                : onRender,
            icon: const Icon(Icons.multitrack_audio),
            label: const Text('Render conversation'),
          ),
          OutlinedButton.icon(
            onPressed: workspace.masterIsCurrent ? onPreview : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Preview master'),
          ),
          OutlinedButton.icon(
            onPressed: workspace.masterIsCurrent ? onExport : null,
            icon: const Icon(Icons.ios_share),
            label: const Text('Save / share WAV'),
          ),
          if (workspace.isGenerating || workspace.isRendering)
            OutlinedButton.icon(
              onPressed: workspace.cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
            ),
        ],
      ),
      if (workspace.isGenerating || workspace.isRendering) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: workspace.progress),
        Text(
          '${workspace.isRendering ? 'Rendering conversation' : 'Generating turns sequentially'} · ${workspace.elapsed}',
        ),
      ],
      if (workspace.masterPath != null)
        Text(
          workspace.masterIsCurrent
              ? 'Clean master ready · mono 48 kHz PCM WAV'
              : 'Previous master retained; render again after changes.',
        ),
    ],
  );
}

Future<void> _editTiming(
  BuildContext context,
  DialogWorkspace workspace,
) async {
  var pause = workspace.defaultPauseMs.toDouble();
  var trim = workspace.trimSilence;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Conversation timing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Default pause: ${pause.round()} ms'),
            Slider(
              value: pause,
              min: 0,
              max: 2000,
              divisions: 80,
              onChanged: (value) => setState(() => pause = value),
            ),
            SwitchListTile(
              title: const Text('Trim digital silence'),
              subtitle: const Text(
                'Conservative; preserves 20 ms at each boundary.',
              ),
              value: trim,
              onChanged: (value) => setState(() => trim = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              workspace.setTiming(pause.round(), trim);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _editTurn(
  BuildContext context,
  DialogWorkspace workspace,
  DialogLineItem line,
) async {
  final text = TextEditingController(text: line.text);
  final pronunciation = TextEditingController(text: line.textOverride ?? '');
  var pause = (line.pauseAfterMs ?? workspace.defaultPauseMs).toDouble();
  var useDefault = line.pauseAfterMs == null;
  var included = line.included;
  final route = DialogRoute<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Edit ${line.speakerName} turn'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Original spoken text',
                  ),
                ),
                TextField(
                  controller: pronunciation,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Explicit pronunciation override (optional)',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Include in conversation'),
                  value: included,
                  onChanged: (value) => setState(() => included = value),
                ),
                SwitchListTile(
                  title: const Text('Use default pause'),
                  value: useDefault,
                  onChanged: (value) => setState(() => useDefault = value),
                ),
                if (!useDefault) ...[
                  Text('Pause after turn: ${pause.round()} ms'),
                  Slider(
                    value: pause,
                    min: 0,
                    max: 2000,
                    divisions: 80,
                    onChanged: (value) => setState(() => pause = value),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              workspace.edit(
                line.copyWith(
                  text: text.text,
                  textOverride: pronunciation.text.trim().isEmpty
                      ? null
                      : pronunciation.text,
                  included: included,
                  pauseAfterMs: useDefault ? null : pause.round(),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
  try {
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
  } finally {
    text.dispose();
    pronunciation.dispose();
  }
}
