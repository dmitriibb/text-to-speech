import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../services/gpu_detector.dart';
import '../state/app_state.dart';

/// Voice selection dropdown and speed slider.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VoiceSettingsControls(
              readyModels: state.readyModels,
              selectedModel: state.selectedModel,
              selectedSpeakerId: state.selectedSpeakerId,
              selectedGenerationLanguage: state.selectedGenerationLanguage,
              speed: state.speed,
              canSelectModel: state.readyModels.isNotEmpty,
              canAdjustSpeed: true,
              onModelSelected: (model) => state.selectModel(model),
              onSpeakerSelected: state.setSpeakerId,
              onGenerationLanguageSelected: state.setGenerationLanguage,
              onSpeedChanged: state.setSpeed,
            ),
            if (state.availableProviders.length > 1) ...[
              const SizedBox(height: 16),
              _buildProviderSelector(context, state),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProviderSelector(BuildContext context, AppState state) {
    return Row(
      children: [
        Icon(
          Icons.memory,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text('Inference:', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 12),
        ...state.availableProviders.map((provider) {
          final isSelected = provider == state.selectedProvider;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(GpuDetector.providerLabels[provider] ?? provider),
              selected: isSelected,
              onSelected: (_) => state.setProvider(provider),
            ),
          );
        }),
      ],
    );
  }
}
