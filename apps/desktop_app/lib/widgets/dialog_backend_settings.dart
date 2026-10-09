import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

/// Desktop file-picker glue injected into the common settings modal.
class DialogBackendSettings extends StatefulWidget {
  const DialogBackendSettings({
    super.key,
    required this.workspace,
    required this.settings,
    required this.onChanged,
  });
  final DialogWorkspace workspace;
  final ModelSynthesisSettings settings;
  final ValueChanged<ModelSynthesisSettings> onChanged;
  @override
  State<DialogBackendSettings> createState() => _DialogBackendSettingsState();
}

class _DialogBackendSettingsState extends State<DialogBackendSettings> {
  late final TextEditingController _transcript;
  late final TextEditingController _style;
  String? _error;
  bool _busy = false;
  Map<String, Object?> get _extensions => widget.settings.extensionValues;
  @override
  void initState() {
    super.initState();
    final asset = _extensions['referenceAsset'];
    _transcript = TextEditingController(
      text: asset is Map ? asset['transcript'] as String? ?? '' : '',
    );
    _style = TextEditingController(text: _extensions['style'] as String? ?? '');
  }

  @override
  void dispose() {
    _transcript.dispose();
    _style.dispose();
    super.dispose();
  }

  void _update(Map<String, Object?> values) =>
      widget.onChanged(widget.settings.copyWith(extensionValues: values));
  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PCM WAV reference', extensions: ['wav']),
        ],
      );
      if (file == null) return;
      final asset = await widget.workspace.importReference(
        File(file.path),
        _transcript.text,
      );
      if (mounted) _update({..._extensions, 'referenceAsset': asset.toJson()});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'VoxCPM2 · clean reference voice reused for every turn. First generation may load the model.',
      ),
      TextField(
        controller: _transcript,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Exact reference transcript',
        ),
        onChanged: (text) {
          final asset = _extensions['referenceAsset'];
          if (asset is Map) {
            _update({
              ..._extensions,
              'referenceAsset': {
                ...Map<String, Object?>.from(asset),
                'transcript': text,
              },
            });
          }
        },
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _pick,
        icon: const Icon(Icons.audio_file_outlined),
        label: const Text('Choose clean reference WAV (1–30 seconds)'),
      ),
      if (_extensions['referenceAsset'] is Map)
        Text(
          'Reference: ${(_extensions['referenceAsset'] as Map)['sha256']}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      TextField(
        controller: _style,
        decoration: const InputDecoration(
          labelText: 'Delivery style (optional)',
        ),
        onChanged: (text) => _update({..._extensions, 'style': text}),
      ),
      Text(
        'Guidance: ${((_extensions['cfg_value'] as num?) ?? 2).toStringAsFixed(1)}',
      ),
      Slider(
        value: ((_extensions['cfg_value'] as num?)?.toDouble() ?? 2).clamp(
          .5,
          5,
        ),
        min: .5,
        max: 5,
        divisions: 18,
        onChanged: (value) => _update({..._extensions, 'cfg_value': value}),
      ),
      Text(
        'Inference steps: ${(_extensions['inference_timesteps'] as num?)?.toInt() ?? 10}',
      ),
      Slider(
        value: ((_extensions['inference_timesteps'] as num?)?.toDouble() ?? 10)
            .clamp(1, 30),
        min: 1,
        max: 30,
        divisions: 29,
        onChanged: (value) =>
            _update({..._extensions, 'inference_timesteps': value.round()}),
      ),
      const Text(
        'Language follows the script. Normalization and denoising are disabled to preserve Russian text.',
      ),
    ],
  );
}
