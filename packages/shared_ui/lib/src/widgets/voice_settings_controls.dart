import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

class VoiceSettingsControls extends StatelessWidget {
  const VoiceSettingsControls({
    super.key,
    required this.readyModels,
    required this.selectedModel,
    required this.selectedSpeakerId,
    required this.selectedGenerationLanguage,
    required this.speed,
    required this.canSelectModel,
    required this.canAdjustSpeed,
    required this.onModelSelected,
    required this.onSpeakerSelected,
    required this.onGenerationLanguageSelected,
    required this.onSpeedChanged,
  });

  final List<InstalledModel> readyModels;
  final InstalledModel? selectedModel;
  final int selectedSpeakerId;
  final String selectedGenerationLanguage;
  final double speed;
  final bool canSelectModel;
  final bool canAdjustSpeed;
  final ValueChanged<InstalledModel> onModelSelected;
  final ValueChanged<int> onSpeakerSelected;
  final ValueChanged<String> onGenerationLanguageSelected;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final hasSpeakers =
        selectedModel != null && selectedModel!.voice.speakers.isNotEmpty;
    final hasLanguageSelection =
        selectedModel != null && selectedModel!.voice.hasLanguageSelection;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout =
            constraints.maxWidth <
            (hasSpeakers && hasLanguageSelection
                ? 920
                : (hasSpeakers || hasLanguageSelection ? 720 : 560));

        if (useCompactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVoiceSelector(context),
              if (hasSpeakers) ...[
                const SizedBox(height: 16),
                _buildSpeakerSelector(context),
              ],
              if (hasLanguageSelection) ...[
                const SizedBox(height: 16),
                _buildLanguageSelector(context),
              ],
              const SizedBox(height: 16),
              _buildSpeedControl(context),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildVoiceSelector(context)),
            if (hasSpeakers) ...[
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildSpeakerSelector(context)),
            ],
            if (hasLanguageSelection) ...[
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildLanguageSelector(context)),
            ],
            const SizedBox(width: 24),
            Expanded(flex: 3, child: _buildSpeedControl(context)),
          ],
        );
      },
    );
  }

  Widget _buildVoiceSelector(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedModel?.voice.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Voice',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: readyModels.map((model) {
        return DropdownMenuItem<String>(
          value: model.voice.id,
          child: Text(
            _voiceLabel(model.voice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      selectedItemBuilder: (context) {
        return readyModels.map<Widget>((model) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _voiceLabel(model.voice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }).toList();
      },
      onChanged: !canSelectModel
          ? null
          : (id) {
              if (id == null) {
                return;
              }

              final model = readyModels.firstWhere(
                (item) => item.voice.id == id,
              );
              onModelSelected(model);
            },
      hint: Text(readyModels.isEmpty ? 'No voices available' : 'Select voice'),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final voice = selectedModel!.voice;
    final languages = voice.generationLanguages;
    final initialLanguage = voice.resolveGenerationLanguage(
      selectedGenerationLanguage,
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
      onChanged: !canSelectModel
          ? null
          : (code) {
              if (code == null) {
                return;
              }
              onGenerationLanguageSelected(code);
            },
    );
  }

  Widget _buildSpeakerSelector(BuildContext context) {
    final speakers = selectedModel?.voice.speakers ?? const <Speaker>[];

    return DropdownButtonFormField<int>(
      initialValue: speakers.any((speaker) => speaker.id == selectedSpeakerId)
          ? selectedSpeakerId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Speaker',
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
      selectedItemBuilder: (context) {
        return speakers.map<Widget>((speaker) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              speaker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }).toList();
      },
      onChanged: (id) {
        if (id == null) {
          return;
        }

        onSpeakerSelected(id);
      },
    );
  }

  Widget _buildSpeedControl(BuildContext context) {
    final clampedSpeed = clampSpeechSpeed(speed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Speed', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              '${clampedSpeed.toStringAsFixed(2)}x',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: clampedSpeed,
          min: speechSpeedMin,
          max: speechSpeedMax,
          divisions: speechSpeedDivisions,
          label: '${clampedSpeed.toStringAsFixed(2)}x',
          onChanged: canAdjustSpeed ? onSpeedChanged : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${speechSpeedMin.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${speechSpeedDefault.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${speechSpeedMax.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  String _voiceLabel(VoiceModel voice) {
    final languages = voice.languageDisplayLabel;
    if (languages.isEmpty) {
      return voice.displayName;
    }
    return '${voice.displayName} · $languages';
  }
}
