import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final ready = state.readyModels;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice and speed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                VoiceSettingsControls(
                  readyModels: ready,
                  selectedModel: state.selectedModel,
                  selectedSpeakerId: state.selectedSpeakerId,
                  speed: state.speed,
                  canSelectModel: state.canSelectModel,
                  canAdjustSpeed: state.canAdjustSpeed,
                  onModelSelected: (model) => state.selectModel(model),
                  onSpeakerSelected: state.setSpeakerId,
                  onSpeedChanged: state.setSpeed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
