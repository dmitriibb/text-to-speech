import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/gpu_detector.dart';
import '../state/app_state.dart';

/// Voice selection dropdown and speed slider.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final hasSpeakers =
            state.selectedModel != null &&
            state.selectedModel!.voice.speakers.isNotEmpty;

        return LayoutBuilder(
          builder: (context, constraints) {
            final useCompactLayout =
                constraints.maxWidth < (hasSpeakers ? 720 : 560);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (useCompactLayout) ...[
                  _buildVoiceSelector(context, state),
                  if (hasSpeakers) ...[
                    const SizedBox(height: 16),
                    _buildSpeakerSelector(context, state),
                  ],
                  const SizedBox(height: 16),
                  _buildSpeedControl(context, state),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildVoiceSelector(context, state),
                      ),
                      if (hasSpeakers) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildSpeakerSelector(context, state),
                        ),
                      ],
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: _buildSpeedControl(context, state),
                      ),
                    ],
                  ),
                if (state.availableProviders.length > 1) ...[
                  const SizedBox(height: 16),
                  _buildProviderSelector(context, state),
                ],
              ],
            );
          },
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _buildVoiceItems(List ready) {
    return ready.map<DropdownMenuItem<String>>((m) {
      return DropdownMenuItem<String>(
        value: m.voice.id,
        child: Text(
          m.voice.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();
  }

  List<Widget> _buildSelectedVoiceItems(BuildContext context, List ready) {
    return ready.map<Widget>((m) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          m.voice.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }).toList();
  }

  List<DropdownMenuItem<int>> _buildSpeakerItems(List speakers) {
    return speakers.map<DropdownMenuItem<int>>((s) {
      return DropdownMenuItem<int>(
        value: s.id,
        child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }

  List<Widget> _buildSelectedSpeakerItems(BuildContext context, List speakers) {
    return speakers.map<Widget>((s) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }).toList();
  }

  Widget _buildVoiceSelector(BuildContext context, AppState state) {
    final ready = state.readyModels;

    return DropdownButtonFormField<String>(
      initialValue: state.selectedModel?.voice.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Voice',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: _buildVoiceItems(ready),
      selectedItemBuilder: (context) =>
          _buildSelectedVoiceItems(context, ready),
      onChanged: ready.isEmpty
          ? null
          : (id) {
              if (id == null) return;
              final model = ready.firstWhere((m) => m.voice.id == id);
              state.selectModel(model);
            },
      hint: Text(ready.isEmpty ? 'No voices available' : 'Select voice'),
    );
  }

  Widget _buildSpeakerSelector(BuildContext context, AppState state) {
    final speakers = state.selectedModel!.voice.speakers;

    return DropdownButtonFormField<int>(
      initialValue: state.selectedSpeakerId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Speaker',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: _buildSpeakerItems(speakers),
      selectedItemBuilder: (context) =>
          _buildSelectedSpeakerItems(context, speakers),
      onChanged: (id) {
        if (id == null) return;
        state.setSpeakerId(id);
      },
    );
  }

  Widget _buildSpeedControl(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Speed', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              '${state.speed.toStringAsFixed(2)}x',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
            Text('0.25x', style: Theme.of(context).textTheme.bodySmall),
            Text('1.0x', style: Theme.of(context).textTheme.bodySmall),
            Text('3.0x', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
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
