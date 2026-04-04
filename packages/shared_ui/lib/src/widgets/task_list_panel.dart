import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import 'audio_playback_controls.dart';
import 'cancel_task_dialog.dart';

typedef TaskAudioCallback = void Function(String outputPath);
typedef TaskSeekCallback = void Function(Duration position);

class TaskPlaybackInfo {
  const TaskPlaybackInfo({
    this.playingTaskId,
    this.activeTaskId,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
  });

  final String? playingTaskId;
  final String? activeTaskId;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
}

class TaskListPanel extends StatelessWidget {
  const TaskListPanel({
    super.key,
    required this.playbackInfo,
    this.onPlay,
    this.onStop,
    this.onSave,
    this.onSeek,
  });

  final TaskPlaybackInfo playbackInfo;
  final TaskAudioCallback? onPlay;
  final VoidCallback? onStop;
  final TaskAudioCallback? onSave;
  final TaskSeekCallback? onSeek;

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
                    onSeek: onSeek,
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
    this.onSeek,
  });

  final LongRunningTask task;
  final TaskManager manager;
  final TaskPlaybackInfo playbackInfo;
  final TaskAudioCallback? onPlay;
  final VoidCallback? onStop;
  final TaskAudioCallback? onSave;
  final TaskSeekCallback? onSeek;

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
    final isActiveThis = widget.playbackInfo.activeTaskId == task.id;

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
          _buildPlaybackControls(context, task, isPlayingThis, isActiveThis),
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
    bool isActiveThis,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AudioPlaybackControls(
            isPlaying: isPlayingThis,
            position: isActiveThis
                ? widget.playbackInfo.position
                : Duration.zero,
            duration: isActiveThis ? widget.playbackInfo.duration : null,
            onTogglePlayback: () {
              if (isPlayingThis) {
                widget.onStop?.call();
              } else if (task.outputPath != null) {
                widget.onPlay?.call(task.outputPath!);
              }
            },
            onSeek: isActiveThis ? widget.onSeek : null,
          ),
          const SizedBox(height: 8),
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
