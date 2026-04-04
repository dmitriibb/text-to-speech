import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';
import 'package:xdg_directories/xdg_directories.dart' as xdg;

/// Manages the model catalog and local model storage.
class ModelService {
  List<VoiceModel> _catalog = [];
  String? _modelsDir;
  http.Client? _activeClient;
  IOSink? _activeSink;
  bool _cancelRequested = false;
  bool _isDownloading = false;

  /// The resolved models directory path.
  String? get modelsDir => _modelsDir;

  /// Reads the approved-model catalog from the bundled asset.
  Future<List<VoiceModel>> loadCatalog() async {
    if (_catalog.isNotEmpty) return _catalog;

    final raw = await rootBundle.loadString('assets/approved_models.json');
    final catalog = ModelCatalog.fromRawJson(raw);
    _catalog = catalog.models;
    return _catalog;
  }

  /// Returns the primary directory where models are stored.
  Future<String> getModelsDirectory() async {
    if (_modelsDir != null) return _modelsDir!;

    // Platform-standard data directory.
    // Linux: ~/.local/share/text-to-speech/models
    // Windows: %APPDATA%/text-to-speech/models
    final String baseDir;
    if (Platform.isLinux) {
      baseDir = p.join(xdg.dataHome.path, 'text-to-speech');
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      baseDir = p.join(appData, 'text-to-speech');
    } else {
      baseDir = p.join(Directory.systemTemp.path, 'text-to-speech');
    }
    _modelsDir = p.join(baseDir, 'models');
    return _modelsDir!;
  }

  /// Scans disk for installed models and returns their status.
  Future<List<InstalledModel>> getInstalledModels() async {
    final catalog = await loadCatalog();
    final modelsDir = await getModelsDirectory();
    final results = <InstalledModel>[];

    for (final voice in catalog) {
      final dir = p.join(modelsDir, voice.installDirName);
      if (await Directory(dir).exists()) {
        final status = await ModelFileValidator.getStatus(dir, voice);
        results.add(
          InstalledModel(voice: voice, status: status, modelDir: dir),
        );
      } else {
        results.add(
          InstalledModel(voice: voice, status: ModelStatus.notInstalled),
        );
      }
    }

    return results;
  }

  /// Downloads and extracts a model archive.
  ///
  /// [onProgress] is called with a value between 0.0 and 1.0.
  Future<void> downloadModel(
    VoiceModel model, {
    void Function(ModelInstallProgress progress)? onProgress,
  }) async {
    final modelsDir = await getModelsDirectory();
    await Directory(modelsDir).create(recursive: true);

    final archiveName = '${model.installDirName}.${model.archiveFormat}';
    final archivePath = p.join(modelsDir, archiveName);
    final archiveFile = File(archivePath);
    final modelDir = Directory(p.join(modelsDir, model.installDirName));
    final client = http.Client();
    IOSink? sink;
    _activeClient = client;
    _cancelRequested = false;
    _isDownloading = true;

    try {
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }

      final request = http.Request('GET', Uri.parse(model.archiveUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download model: HTTP ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      sink = archiveFile.openWrite();
      _activeSink = sink;

      await for (final chunk in response.stream) {
        _throwIfCancelled();
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(
            ModelInstallProgress(
              stage: ModelInstallStage.downloading,
              progress: totalBytes > 0
                  ? 0.8 * receivedBytes / totalBytes
                  : null,
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes > 0 ? totalBytes : null,
            ),
          );
        }
      }
      await sink.close();
      _activeSink = null;
      _throwIfCancelled();

      onProgress?.call(
        ModelInstallProgress(
          stage: ModelInstallStage.extracting,
          progress: null,
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes > 0 ? totalBytes : null,
        ),
      );
      await ModelArchiveExtractor.extractArchive(
        archivePath: archivePath,
        archiveFormat: model.archiveFormat,
        outputDir: modelsDir,
      );
      _throwIfCancelled();
      await ModelFileValidator.normalizeExtractedModelDir(modelDir.path, model);

      onProgress?.call(
        ModelInstallProgress(
          stage: ModelInstallStage.validating,
          progress: null,
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes > 0 ? totalBytes : null,
        ),
      );

      final status = await ModelFileValidator.getStatus(modelDir.path, model);
      _throwIfCancelled();
      if (status != ModelStatus.ready) {
        final missing = await ModelFileValidator.missingEntries(
          modelDir.path,
          model,
        );
        final found = await ModelFileValidator.listTopLevelEntries(
          modelDir.path,
        );
        final foundSummary = found.isEmpty ? 'nothing' : found.join(', ');
        throw Exception(
          'Model extraction incomplete in ${modelDir.path}: '
          'missing ${missing.join(', ')}. '
          'Found: $foundSummary',
        );
      }

      onProgress?.call(
        ModelInstallProgress(
          stage: ModelInstallStage.completed,
          progress: 1.0,
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes > 0 ? totalBytes : null,
        ),
      );
    } catch (error) {
      if (_cancelRequested) {
        throw const ModelDownloadCancelledException();
      }
      rethrow;
    } finally {
      try {
        await _activeSink?.close();
      } catch (_) {}
      _activeSink = null;
      client.close();
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
      if (_cancelRequested && await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
      _activeClient = null;
      _isDownloading = false;
      _cancelRequested = false;
    }
  }

  Future<void> cancelActiveDownload() async {
    if (!_isDownloading) {
      return;
    }

    _cancelRequested = true;
    _activeClient?.close();
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const ModelDownloadCancelledException();
    }
  }

  void dispose() {
    _activeClient?.close();
  }
}
