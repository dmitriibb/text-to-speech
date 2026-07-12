import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

typedef ModelSettingsExtensionBuilder =
    Widget Function(
      BuildContext context,
      InstalledModel model,
      ModelSynthesisSettings settings,
      ValueChanged<ModelSynthesisSettings> onChanged,
    );

/// A model dropdown paired with a capability-driven settings dialog.
class ModelSelector extends StatelessWidget {
  const ModelSelector({
    super.key,
    required this.readyModels,
    required this.selectedModel,
    required this.settings,
    required this.onModelSelected,
    required this.onSettingsChanged,
    this.enabled = true,
    this.extensionBuilder,
    this.label = 'AI model',
  });

  final List<InstalledModel> readyModels;
  final InstalledModel? selectedModel;
  final ModelSynthesisSettings settings;
  final ValueChanged<InstalledModel> onModelSelected;
  final ValueChanged<ModelSynthesisSettings> onSettingsChanged;
  final bool enabled;
  final ModelSettingsExtensionBuilder? extensionBuilder;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(selectedModel?.voice.id),
            initialValue: selectedModel?.voice.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            items: readyModels
                .map(
                  (model) => DropdownMenuItem<String>(
                    value: model.voice.id,
                    child: Text(
                      _modelLabel(model.voice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: !enabled
                ? null
                : (id) {
                    if (id == null) return;
                    onModelSelected(
                      readyModels.firstWhere((model) => model.voice.id == id),
                    );
                  },
            hint: Text(
              readyModels.isEmpty ? 'No models available' : 'Select model',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: selectedModel == null
              ? 'Select a model first'
              : 'Model settings',
          onPressed: selectedModel == null
              ? null
              : () => _showSettings(context, selectedModel!),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  Future<void> _showSettings(BuildContext context, InstalledModel model) async {
    final result = await showDialog<ModelSynthesisSettings>(
      context: context,
      builder: (context) => _ModelSettingsDialog(
        model: model,
        initialSettings: settings,
        extensionBuilder: extensionBuilder,
      ),
    );
    if (result != null) {
      onSettingsChanged(result);
    }
  }

  String _modelLabel(VoiceModel voice) {
    final languages = voice.languageDisplayLabel;
    return languages.isEmpty
        ? voice.displayName
        : '${voice.displayName} · $languages';
  }
}

class _ModelSettingsDialog extends StatefulWidget {
  const _ModelSettingsDialog({
    required this.model,
    required this.initialSettings,
    this.extensionBuilder,
  });

  final InstalledModel model;
  final ModelSynthesisSettings initialSettings;
  final ModelSettingsExtensionBuilder? extensionBuilder;

  @override
  State<_ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends State<_ModelSettingsDialog> {
  late ModelSynthesisSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.model.voice;
    return AlertDialog(
      title: Text('${voice.displayName} settings'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _slider(
                label: 'Volume',
                value: _settings.volume,
                min: modelVolumeMin,
                max: modelVolumeMax,
                divisions: modelVolumeDivisions,
                valueLabel: '${_settings.volume.toStringAsFixed(2)}×',
                onChanged: (value) =>
                    _update(_settings.copyWith(volume: value)),
              ),
              const SizedBox(height: 16),
              _slider(
                label: 'Speed',
                value: _settings.speed,
                min: speechSpeedMin,
                max: speechSpeedMax,
                divisions: speechSpeedDivisions,
                valueLabel: '${_settings.speed.toStringAsFixed(2)}×',
                onChanged: (value) => _update(_settings.copyWith(speed: value)),
              ),
              if (voice.speakers.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue:
                      voice.speakers.any(
                        (speaker) => speaker.id == _settings.speakerId,
                      )
                      ? _settings.speakerId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Voice / speaker',
                    border: OutlineInputBorder(),
                  ),
                  items: voice.speakers
                      .map(
                        (speaker) => DropdownMenuItem<int>(
                          value: speaker.id,
                          child: Text(speaker.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _update(_settings.copyWith(speakerId: value));
                    }
                  },
                ),
              ],
              if (voice.hasLanguageSelection) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: voice.resolveGenerationLanguage(
                    _settings.generationLanguage,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                  ),
                  items: voice.generationLanguages
                      .map(
                        (language) => DropdownMenuItem<String>(
                          value: language.code,
                          child: Text(language.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _update(_settings.copyWith(generationLanguage: value));
                    }
                  },
                ),
              ],
              if (widget.extensionBuilder != null) ...[
                const SizedBox(height: 16),
                widget.extensionBuilder!(
                  context,
                  widget.model,
                  _settings,
                  _update,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_settings),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text(label), const Spacer(), Text(valueLabel)]),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(min.toStringAsFixed(1)),
            Text(max.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  void _update(ModelSynthesisSettings settings) {
    setState(() => _settings = settings);
  }
}
