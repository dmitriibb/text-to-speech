import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/long_running_task.dart';
import '../state/app_state.dart';

class ActiveTaskList extends StatelessWidget {
  const ActiveTaskList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final tasks = state.activeTasks;
        if (tasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Background tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < tasks.length; index++) ...[
                  _ActiveTaskRow(task: tasks[index]),
                  if (index < tasks.length - 1) const Divider(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveTaskRow extends StatelessWidget {
  const _ActiveTaskRow({required this.task});

  final LongRunningTask task;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          switch (task.type) {
            LongRunningTaskType.preloadModel => Icons.tune,
            LongRunningTaskType.synthesizeSpeech => Icons.graphic_eq,
          },
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${state.describeTaskStatus(task)} • ${state.formatTaskElapsed(task)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: task.canCancel
              ? () => _confirmCancel(context, task, state)
              : null,
          tooltip: 'Cancel task',
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    LongRunningTask task,
    AppState state,
  ) async {
    final shouldCancel = await showDialog<bool>(
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

    if (shouldCancel == true) {
      await state.cancelTask(task.id);
    }
  }
}