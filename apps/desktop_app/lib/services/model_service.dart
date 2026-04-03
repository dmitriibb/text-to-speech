import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:xdg_directories/xdg_directories.dart' as xdg;

import '../models/voice_model.dart';

/// Manages the model catalog and local model storage.
class ModelService {
  List<VoiceModel> _catalog = [];
  String? _modelsDir;

  /// The resolved models directory path.
  String? get modelsDir => _modelsDir;

  /// Reads the approved-model catalog from the bundled asset.
  Future<List<VoiceModel>> loadCatalog() async {
    if (_catalog.isNotEmpty) return _catalog;

    final raw = await rootBundle.loadString('assets/approved_models.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final models = json['models'] as List<dynamic>;

    _catalog = models
        .map((m) => VoiceModel.fromJson(m as Map<String, dynamic>))
        .toList();
    return _catalog;
  }

  /// Returns the primary directory where models are stored.
  Future<String> getModelsDirectory() async {
    if (_modelsDir != null) return _modelsDir!;

    // Allow override via environment variable.
    final envPath = Platform.environment['TTS_MODELS_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      _modelsDir = envPath;
      return _modelsDir!;
    }

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

  /// All directories to search for installed models.
  Future<List<String>> _getSearchPaths() async {
    final paths = <String>[await getModelsDirectory()];

    // Development convenience: check workspace models/ directory.
    // Walk up from executable to find the monorepo root.
    final exeDir = p.dirname(Platform.resolvedExecutable);
    // In a flutter build, the exe is at:
    //   apps/desktop_app/build/linux/x64/release/bundle/desktop_app
    // So monorepo root is 7 levels up.
    var candidate = exeDir;
    for (var i = 0; i < 8; i++) {
      final modelsCandidate = p.join(candidate, 'models');
      if (await Directory(modelsCandidate).exists()) {
        if (!paths.contains(modelsCandidate)) {
          paths.add(modelsCandidate);
        }
        break;
      }
      candidate = p.dirname(candidate);
    }

    return paths;
  }

  /// Scans disk for installed models and returns their status.
  Future<List<InstalledModel>> getInstalledModels() async {
    final catalog = await loadCatalog();
    final searchPaths = await _getSearchPaths();
    final results = <InstalledModel>[];

    for (final voice in catalog) {
      InstalledModel? found;
      for (final basePath in searchPaths) {
        final dir = p.join(basePath, voice.installDirName);
        if (await Directory(dir).exists()) {
          final status = await _checkModelFiles(dir, voice);
          if (status == ModelStatus.ready) {
            found = InstalledModel(
              voice: voice,
              status: ModelStatus.ready,
              modelDir: dir,
            );
            break;
          } else {
            found = InstalledModel(
              voice: voice,
              status: ModelStatus.incomplete,
              modelDir: dir,
            );
          }
        }
      }
      results.add(found ??
          InstalledModel(voice: voice, status: ModelStatus.notInstalled));
    }

    return results;
  }

  /// Checks whether the required model files exist.
  Future<ModelStatus> _checkModelFiles(String dir, VoiceModel voice) async {
    final modelPath = p.join(dir, voice.modelFile);
    final tokensPath = p.join(dir, voice.tokensFile);

    if (!await File(modelPath).exists()) return ModelStatus.incomplete;
    if (!await File(tokensPath).exists()) return ModelStatus.incomplete;

    if (voice.dataDir.isNotEmpty) {
      final dataPath = p.join(dir, voice.dataDir);
      if (!await Directory(dataPath).exists()) return ModelStatus.incomplete;
    }

    return ModelStatus.ready;
  }

  /// Downloads and extracts a model archive.
  ///
  /// [onProgress] is called with a value between 0.0 and 1.0.
  Future<void> downloadModel(
    VoiceModel model, {
    void Function(double progress)? onProgress,
  }) async {
    final modelsDir = await getModelsDirectory();
    await Directory(modelsDir).create(recursive: true);

    final archiveName = '${model.installDirName}.${model.archiveFormat}';
    final archivePath = p.join(modelsDir, archiveName);
    final archiveFile = File(archivePath);

    // Download with progress.
    final request = http.Request('GET', Uri.parse(model.archiveUrl));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download model: HTTP ${response.statusCode}',
      );
    }

    final totalBytes = response.contentLength ?? 0;
    var receivedBytes = 0;
    final sink = archiveFile.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        // Report download as 0-80% of total progress.
        onProgress(0.8 * receivedBytes / totalBytes);
      }
    }
    await sink.close();

    // Extract archive.
    onProgress?.call(0.85);

    if (model.archiveFormat == 'tar.bz2') {
      final result = await Process.run(
        'tar',
        ['xjf', archivePath, '-C', modelsDir],
      );
      if (result.exitCode != 0) {
        throw Exception('Failed to extract model: ${result.stderr}');
      }
    } else {
      throw Exception('Unsupported archive format: ${model.archiveFormat}');
    }

    // Clean up archive.
    await archiveFile.delete();
    onProgress?.call(1.0);
  }
}
