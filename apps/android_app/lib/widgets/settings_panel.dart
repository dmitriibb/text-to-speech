import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                DropdownButtonFormField<String>(
                  initialValue: state.selectedModel?.voice.id,
                  decoration: const InputDecoration(
                    labelText: 'Voice',
                    border: OutlineInputBorder(),
                  ),
                  items: ready.map((model) {
                    return DropdownMenuItem(
                      value: model.voice.id,
                      child: Text(model.voice.displayName),
                    );
                  }).toList(),
                  onChanged: ready.isEmpty
                      ? null
                      : (id) {
                          if (id == null) {
                            return;
                          }

                          final nextModel =
                              ready.firstWhere((model) => model.voice.id == id);
                          state.selectModel(nextModel);
                        },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Speed',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${state.speed.toStringAsFixed(2)}x',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                Slider(
                  value: state.speed,
                  min: 0.25,
                  max: 3.0,
                  divisions: 22,
                  label: '${state.speed.toStringAsFixed(2)}x',
                  onChanged: (value) => state.setSpeed(value),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.25x', style: Theme.of(context).textTheme.bodySmall),
                    Text('1.0x', style: Theme.of(context).textTheme.bodySmall),
                    Text('3.0x', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}