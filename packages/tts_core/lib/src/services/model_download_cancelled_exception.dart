class ModelDownloadCancelledException implements Exception {
  const ModelDownloadCancelledException();

  @override
  String toString() => 'Model download cancelled';
}
