import 'dart:async';

import '../models/long_running_task.dart';

abstract class BackgroundTaskExecutor {
  Future<void> initialize();

  Future<void> submit(TaskRequest request);

  void requestCancel(String taskId);

  Stream<TaskResult> get results;

  void dispose();
}
