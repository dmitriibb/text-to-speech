import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

import 'model_selector.dart';

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
    required this.onSpeakerSelected,
    required this.onLanguageSelected,
    required this.onVolumeChanged,
    required this.speed,
    required this.onSpeedChanged,
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
  final void Function(String speakerName, int speakerId) onSpeakerSelected;
  final void Function(String speakerName, String language) onLanguageSelected;
  final void Function(String speakerName, int volume) onVolumeChanged;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Center(
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: onPasteFromClipboard,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from buffer'),
          ),
        ),
      );
    }

    final speakers = _orderedSpeakerNames();
    final hasPlayableLines = lines.any((line) => line.hasPlayableAudio);
    final hasTextLines = lines.any((line) => line.hasText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SpeakerSettingsList(
          speakers: speakers,
          readyModels: readyModels,
          speakerSettings: speakerSettings,
          onModelSelected: onModelSelected,
          onSpeakerSelected: onSpeakerSelected,
          onLanguageSelected: onLanguageSelected,
          onVolumeChanged: onVolumeChanged,
          speed: speed,
          onSpeedChanged: onSpeedChanged,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: hasTextLines && !isGenerating ? onGenerate : null,
              icon: Icon(
                isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
              ),
              label: Text(isGenerating ? 'Generating' : 'Generate'),
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

class _SpeakerSettingsList extends StatelessWidget {
  const _SpeakerSettingsList({
    required this.speakers,
    required this.readyModels,
    required this.speakerSettings,
    required this.onModelSelected,
    required this.onSpeakerSelected,
    required this.onLanguageSelected,
    required this.onVolumeChanged,
    required this.speed,
    required this.onSpeedChanged,
  });

  final List<String> speakers;
  final List<InstalledModel> readyModels;
  final Map<String, DialogSpeakerSettings> speakerSettings;
  final void Function(String speakerName, InstalledModel model) onModelSelected;
  final void Function(String speakerName, int speakerId) onSpeakerSelected;
  final void Function(String speakerName, String language) onLanguageSelected;
  final void Function(String speakerName, int volume) onVolumeChanged;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

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
            onSpeakerSelected: onSpeakerSelected,
            onLanguageSelected: onLanguageSelected,
            onVolumeChanged: onVolumeChanged,
            speed: speed,
            onSpeedChanged: onSpeedChanged,
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
    required this.onSpeakerSelected,
    required this.onLanguageSelected,
    required this.onVolumeChanged,
    required this.speed,
    required this.onSpeedChanged,
  });

  final String speakerName;
  final List<InstalledModel> readyModels;
  final DialogSpeakerSettings? settings;
  final void Function(String speakerName, InstalledModel model) onModelSelected;
  final void Function(String speakerName, int speakerId) onSpeakerSelected;
  final void Function(String speakerName, String language) onLanguageSelected;
  final void Function(String speakerName, int volume) onVolumeChanged;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final selectedModel = _selectedModel();
    final modelSettings = selectedModel == null
        ? const ModelSynthesisSettings()
        : ModelSynthesisSettings.defaultsFor(selectedModel.voice).copyWith(
            speed: speed,
            volume: dialogVolumeToGain(settings?.volume ?? dialogVolumeDefault),
            speakerId: settings?.speakerId,
            generationLanguage: settings?.generationLanguage,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 160, child: _SpeakerNameLabel(name: speakerName)),
        const SizedBox(width: 12),
        Expanded(
          child: ModelSelector(
            readyModels: readyModels,
            selectedModel: selectedModel,
            settings: modelSettings,
            enabled: readyModels.isNotEmpty,
            onModelSelected: (model) => onModelSelected(speakerName, model),
            onSettingsChanged: (next) {
              onSpeedChanged(next.speed);
              onSpeakerSelected(speakerName, next.speakerId);
              onLanguageSelected(speakerName, next.generationLanguage);
              onVolumeChanged(
                speakerName,
                (next.volume * dialogVolumeDefault).round(),
              );
            },
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

  // ignore: unused_element
  Widget _buildModelSelector(
    BuildContext context,
    InstalledModel? selectedModel,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: selectedModel?.voice.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'AI model',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: readyModels.map((model) {
        return DropdownMenuItem<String>(
          value: model.voice.id,
          child: Text(
            _modelLabel(model.voice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: readyModels.isEmpty
          ? null
          : (modelId) {
              if (modelId == null) {
                return;
              }
              final model = readyModels.firstWhere(
                (item) => item.voice.id == modelId,
              );
              onModelSelected(speakerName, model);
            },
      hint: Text(readyModels.isEmpty ? 'No models available' : 'Select model'),
    );
  }

  // ignore: unused_element
  Widget _buildVoiceSelector(
    BuildContext context,
    List<Speaker> speakers,
    int? selectedSpeakerId,
  ) {
    final initialSpeakerId =
        speakers.any((speaker) => speaker.id == selectedSpeakerId)
        ? selectedSpeakerId
        : null;

    return DropdownButtonFormField<int>(
      initialValue: initialSpeakerId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Voice',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: speakers.map((speaker) {
        return DropdownMenuItem<int>(
          value: speaker.id,
          child: Text(
            speaker.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (speakerId) {
        if (speakerId == null) {
          return;
        }
        onSpeakerSelected(speakerName, speakerId);
      },
    );
  }

  // ignore: unused_element
  Widget _buildLanguageSelector(
    BuildContext context,
    List<VoiceLanguage> languages,
  ) {
    final voice = _selectedModel()?.voice;
    final initialLanguage = voice?.resolveGenerationLanguage(
      settings?.generationLanguage,
    );

    return DropdownButtonFormField<String>(
      initialValue:
          languages.any((language) => language.code == initialLanguage)
          ? initialLanguage
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Language',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: languages.map((language) {
        return DropdownMenuItem<String>(
          value: language.code,
          child: Text(
            language.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (language) {
        if (language == null) {
          return;
        }
        onLanguageSelected(speakerName, language);
      },
    );
  }

  String _modelLabel(VoiceModel voice) {
    final languages = voice.languageDisplayLabel;
    if (languages.isEmpty) {
      return voice.displayName;
    }
    return '${voice.displayName} · $languages';
  }
}

// ignore: unused_element
class _VolumeStepper extends StatelessWidget {
  const _VolumeStepper({required this.volume, required this.onChanged});

  final int volume;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedVolume = clampDialogVolume(volume);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease volume',
              onPressed: normalizedVolume > dialogVolumeMin
                  ? () => onChanged(normalizedVolume - 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '$normalizedVolume',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Increase volume',
              onPressed: normalizedVolume < dialogVolumeMax
                  ? () => onChanged(normalizedVolume + 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
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
  });

  final DialogLineItem line;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = line.hasText
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          );

    return Card(
      elevation: isActive ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              child: Text(
                line.speakerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                line.hasText ? line.text : 'Text removed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 4),
            _LineStatusIcon(status: line.status),
          ],
        ),
      ),
    );
  }
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
