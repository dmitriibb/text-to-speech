import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

Future<bool> showCancelTaskDialog(
  BuildContext context,
  LongRunningTask task,
) async {
  return _showTaskActionDialog(
    context: context,
    title: 'Cancel task?',
    content: task.label,
    confirmLabel: 'Yes',
  );
}

Future<bool> showRemoveGeneratedAudioDialog(
  BuildContext context,
  LongRunningTask task,
) async {
  return _showTaskActionDialog(
    context: context,
    title: 'Remove generated audio?',
    content:
        '${task.label}\n\nThis removes the generated WAV file from local storage.',
    confirmLabel: 'Remove',
  );
}

Future<bool> _showTaskActionDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
