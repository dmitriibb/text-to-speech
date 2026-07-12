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
                  'AI model',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                ModelSelector(
                  readyModels: ready,
                  selectedModel: state.selectedModel,
                  settings: state.modelSettings,
                  enabled: state.canSelectModel,
                  onModelSelected: (model) => state.selectModel(model),
                  onSettingsChanged: state.applyModelSettings,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
