import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/voice_model.dart';
import '../state/app_state.dart';

/// Voice selection dropdown and speed slider.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Voice selector.
            Expanded(
              flex: 2,
              child: _buildVoiceSelector(context, state),
            ),
            const SizedBox(width: 24),
            // Speed control.
            Expanded(
              flex: 3,
              child: _buildSpeedControl(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVoiceSelector(BuildContext context, AppState state) {
    final ready = state.readyModels;

    return DropdownButtonFormField<String>(
      value: state.selectedModel?.voice.id,
      decoration: const InputDecoration(
        labelText: 'Voice',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: ready.map((m) {
        return DropdownMenuItem(
          value: m.voice.id,
          child: Text(m.voice.displayName),
        );
      }).toList(),
      onChanged: ready.isEmpty
          ? null
          : (id) {
              if (id == null) return;
              final model = ready.firstWhere((m) => m.voice.id == id);
              state.selectModel(model);
            },
      hint: Text(
        ready.isEmpty ? 'No voices available' : 'Select voice',
      ),
    );
  }

  Widget _buildSpeedControl(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Speed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              '${state.speed.toStringAsFixed(2)}x',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
          onChanged: (v) => state.setSpeed(v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0.25x',
                style: Theme.of(context).textTheme.bodySmall),
            Text('1.0x',
                style: Theme.of(context).textTheme.bodySmall),
            Text('3.0x',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
