enum ModelInstallStage { downloading, extracting, validating, completed }

extension ModelInstallStageLabel on ModelInstallStage {
  String get label {
    switch (this) {
      case ModelInstallStage.downloading:
        return 'Downloading';
      case ModelInstallStage.extracting:
        return 'Extracting';
      case ModelInstallStage.validating:
        return 'Validating';
      case ModelInstallStage.completed:
        return 'Completed';
    }
  }
}

class ModelInstallProgress {
  const ModelInstallProgress({
    required this.stage,
    this.progress,
    this.downloadedBytes,
    this.totalBytes,
  });

  final ModelInstallStage stage;
  final double? progress;
  final int? downloadedBytes;
  final int? totalBytes;
}
