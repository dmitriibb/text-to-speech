import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import 'cancel_task_dialog.dart';

typedef TaskAudioCallback = void Function(String outputPath);

class TaskPlaybackInfo {
  const TaskPlaybackInfo({this.playingTaskId, this.isPlaying = false});

  final String? playingTaskId;
  final bool isPlaying;
}

class TaskListPanel extends StatelessWidget {
  const TaskListPanel({
    super.key,
    required this.playbackInfo,
    this.onPlay,
    this.onStop,
    this.onSave,
  });

  final TaskPlaybackInfo playbackInfo;
  final TaskAudioCallback? onPlay;
  final VoidCallback? onStop;
  final TaskAudioCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskManager>(
      builder: (context, manager, _) {
        final tasks = manager.tasks;
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < tasks.length; i++) ...[
                  _TaskRow(
                    task: tasks[i],
                    manager: manager,
                    playbackInfo: playbackInfo,
                    onPlay: onPlay,
                    onStop: onStop,
                    onSave: onSave,
                  ),
                  if (i < tasks.length - 1) const Divider(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    required this.task,
    required this.manager,
    required this.playbackInfo,
    this.onPlay,
    this.onStop,
    this.onSave,
  });

  final LongRunningTask task;
  final TaskManager manager;
  final TaskPlaybackInfo playbackInfo;
  final TaskAudioCallback? onPlay;
  final VoidCallback? onStop;
  final TaskAudioCallback? onSave;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final manager = widget.manager;
    final isPlayingThis =
        widget.playbackInfo.playingTaskId == task.id &&
        widget.playbackInfo.isPlaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: task.hasPlayableAudio
              ? () => setState(() => _expanded = !_expanded)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _buildStatusIcon(context, task),
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
                        '${manager.describeStatus(task)} • ${manager.formatElapsed(task)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (task.canCancel)
                  IconButton(
                    onPressed: () => _handleCancel(context, task, manager),
                    tooltip: 'Cancel task',
                    icon: const Icon(Icons.close, size: 20),
                  )
                else if (!task.isActive)
                  IconButton(
                    onPressed: () => manager.dismissTask(task.id),
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && task.hasPlayableAudio)
          _buildPlaybackControls(context, task, isPlayingThis),
      ],
    );
  }

  Widget _buildStatusIcon(BuildContext context, LongRunningTask task) {
    switch (task.status) {
      case LongRunningTaskStatus.queued:
        return Icon(
          Icons.hourglass_empty,
          color: Theme.of(context).colorScheme.outline,
        );
      case LongRunningTaskStatus.running:
      case LongRunningTaskStatus.cancelling:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      case LongRunningTaskStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green.shade600);
      case LongRunningTaskStatus.failed:
        return Icon(Icons.error, color: Theme.of(context).colorScheme.error);
      case LongRunningTaskStatus.cancelled:
        return Icon(
          Icons.cancel,
          color: Theme.of(context).colorScheme.outline,
        );
    }
  }

  Widget _buildPlaybackControls(
    BuildContext context,
    LongRunningTask task,
    bool isPlayingThis,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 8, bottom: 4),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () {
              if (isPlayingThis) {
                widget.onStop?.call();
              } else if (task.outputPath != null) {
                widget.onPlay?.call(task.outputPath!);
              }
            },
            icon: Icon(isPlayingThis ? Icons.stop : Icons.play_arrow),
            label: Text(isPlayingThis ? 'Stop' : 'Play'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: task.outputPath != null
                ? () => widget.onSave?.call(task.outputPath!)
                : null,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancel(
    BuildContext context,
    LongRunningTask task,
    TaskManager manager,
  ) async {
    final confirmed = await showCancelTaskDialog(context, task);
    if (confirmed) {
      await manager.cancelTask(task.id);
    }
  }
}
