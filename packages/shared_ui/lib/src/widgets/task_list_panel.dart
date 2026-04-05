import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import 'audio_playback_controls.dart';
import 'cancel_task_dialog.dart';

typedef TaskAudioCallback = void Function(String outputPath);
typedef TaskSeekCallback = void Function(Duration position);
typedef TaskActionCallback = Future<void> Function(LongRunningTask task);

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
    this.onCancelTask,
    this.onDismissTask,
  });

  final TaskPlaybackInfo playbackInfo;
  final TaskAudioCallback? onPlay;
  final VoidCallback? onStop;
  final TaskAudioCallback? onSave;
  final TaskSeekCallback? onSeek;
  final TaskActionCallback? onCancelTask;
  final TaskActionCallback? onDismissTask;

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
                Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
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
                    onCancelTask: onCancelTask,
                    onDismissTask: onDismissTask,
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
    this.onCancelTask,
    this.onDismissTask,
  });

  final LongRunningTask task;
  final TaskManager manager;
  final TaskPlaybackInfo playbackInfo;
  final TaskAudioCallback? onPlay;
  final VoidCallback? onStop;
  final TaskAudioCallback? onSave;
  final TaskSeekCallback? onSeek;
  final TaskActionCallback? onCancelTask;
  final TaskActionCallback? onDismissTask;

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
          onTap: task.hasExpandableDetails
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
                    onPressed: () => _handleDismiss(task, manager),
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded)
          _buildExpandedContent(context, task, isPlayingThis, isActiveThis),
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
        return Icon(Icons.cancel, color: Theme.of(context).colorScheme.outline);
    }
  }

  Widget _buildPlaybackControls(
    BuildContext context,
    LongRunningTask task,
    bool isPlayingThis,
    bool isActiveThis,
  ) {
    return AudioPlaybackControls(
      isPlaying: isPlayingThis,
      position: isActiveThis ? widget.playbackInfo.position : Duration.zero,
      duration: isActiveThis ? widget.playbackInfo.duration : null,
      onTogglePlayback: () {
        if (isPlayingThis) {
          widget.onStop?.call();
        } else if (task.outputPath != null) {
          widget.onPlay?.call(task.outputPath!);
        }
      },
      secondaryActionLabel: 'Export',
      onSecondaryAction: task.outputPath != null
          ? () => widget.onSave?.call(task.outputPath!)
          : null,
      onSeek: isActiveThis ? widget.onSeek : null,
    );
  }

  Widget _buildExpandedContent(
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
          if (task.type == LongRunningTaskType.installModel)
            _buildInstallDetails(context, task),
          if (task.errorMessage != null &&
              task.type != LongRunningTaskType.installModel)
            _buildErrorDetails(context, task.errorMessage!),
          if (task.hasPlayableAudio) ...[
            if (task.type == LongRunningTaskType.installModel)
              const SizedBox(height: 12),
            _buildPlaybackControls(context, task, isPlayingThis, isActiveThis),
          ],
        ],
      ),
    );
  }

  Widget _buildInstallDetails(BuildContext context, LongRunningTask task) {
    final progressValue = task.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.statusText ?? widget.manager.describeStatus(task),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progressValue),
        const SizedBox(height: 8),
        if (task.totalBytes != null)
          Text(
            '${_formatMegabytes(task.transferredBytes ?? 0)} / ${_formatMegabytes(task.totalBytes!)}',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else if (task.transferredBytes != null)
          Text(
            _formatMegabytes(task.transferredBytes!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (task.status == LongRunningTaskStatus.completed) ...[
          const SizedBox(height: 8),
          Text(
            'Model install completed.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (task.errorMessage != null) ...[
          const SizedBox(height: 8),
          _buildErrorDetails(context, task.errorMessage!),
        ],
      ],
    );
  }

  Widget _buildErrorDetails(BuildContext context, String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        errorMessage,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }

  String _formatMegabytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  Future<void> _handleCancel(
    BuildContext context,
    LongRunningTask task,
    TaskManager manager,
  ) async {
    final confirmed = await showCancelTaskDialog(context, task);
    if (confirmed) {
      if (widget.onCancelTask != null) {
        await widget.onCancelTask!(task);
      } else {
        await manager.cancelTask(task.id);
      }
    }
  }

  Future<void> _handleDismiss(LongRunningTask task, TaskManager manager) async {
    if (widget.onDismissTask != null) {
      await widget.onDismissTask!(task);
    } else {
      manager.dismissTask(task.id);
    }
  }
}
