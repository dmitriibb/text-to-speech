import 'package:flutter/material.dart';
import 'package:tts_core/tts_core.dart';

Future<bool> showCancelTaskDialog(BuildContext context, LongRunningTask task) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Cancel task?'),
        content: Text(task.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );
  return result == true;
}
