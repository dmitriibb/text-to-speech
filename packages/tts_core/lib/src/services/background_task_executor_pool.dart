import 'dart:async';

import '../models/long_running_task.dart';
import 'background_task_executor.dart';

typedef BackgroundTaskPoolExecutorFactory = BackgroundTaskExecutor Function();

class BackgroundTaskExecutorPool implements BackgroundTaskExecutor {
  BackgroundTaskExecutorPool({
    required BackgroundTaskPoolExecutorFactory executorFactory,
    int workerCount = 1,
  }) : _executorFactory = executorFactory,
       _workerCount = _normalizeWorkerCount(workerCount);

  final BackgroundTaskPoolExecutorFactory _executorFactory;
  final List<BackgroundTaskExecutor> _executors = <BackgroundTaskExecutor>[];
  final Map<String, BackgroundTaskExecutor> _taskExecutors =
      <String, BackgroundTaskExecutor>{};
  final StreamController<TaskResult> _resultsController =
      StreamController<TaskResult>.broadcast();
  final List<StreamSubscription<TaskResult>> _subscriptions =
      <StreamSubscription<TaskResult>>[];

  int _workerCount;
  int _nextExecutorIndex = 0;
  bool _initialized = false;

  @override
  Stream<TaskResult> get results => _resultsController.stream;

  int get workerCount => _workerCount;

  set workerCount(int value) {
    _workerCount = _normalizeWorkerCount(value);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    for (var index = 0; index < _workerCount; index++) {
      await _addExecutor();
    }
    _initialized = true;
  }

  @override
  Future<void> submit(TaskRequest request) async {
    await initialize();
    final executor = _nextExecutor();
    _taskExecutors[request.taskId] = executor;
    await executor.submit(request);
  }

  @override
  void requestCancel(String taskId) {
    _taskExecutors[taskId]?.requestCancel(taskId);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();

    for (final executor in _executors) {
      executor.dispose();
    }
    _executors.clear();
    _taskExecutors.clear();
    unawaited(_resultsController.close());
    _initialized = false;
  }

  Future<void> _addExecutor() async {
    final executor = _executorFactory();
    _executors.add(executor);
    _subscriptions.add(
      executor.results.listen((result) {
        _taskExecutors.remove(result.taskId);
        _resultsController.add(result);
      }),
    );
    await executor.initialize();
  }

  BackgroundTaskExecutor _nextExecutor() {
    final executor = _executors[_nextExecutorIndex % _executors.length];
    _nextExecutorIndex = (_nextExecutorIndex + 1) % _executors.length;
    return executor;
  }

  static int _normalizeWorkerCount(int value) {
    return value < 1 ? 1 : value;
  }
}
