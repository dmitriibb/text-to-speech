import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tts_core/tts_core.dart';

class ModelService {
  final http.Client _client = http.Client();

  ModelCatalog? _catalog;
  String? _modelsDir;

  Future<ModelCatalog> loadCatalog() async {
    if (_catalog != null) {
      return _catalog!;
    }

    final raw = await rootBundle.loadString('assets/approved_models.json');
    _catalog = ModelCatalog.fromRawJson(raw);
    return _catalog!;
  }

  Future<List<VoiceModel>> getCatalogModels() async {
    final catalog = await loadCatalog();
    return catalog.models;
  }

  Future<String> getModelsDirectory() async {
    if (_modelsDir != null) {
      return _modelsDir!;
    }

    final appSupportDir = await getApplicationSupportDirectory();
    _modelsDir = p.join(appSupportDir.path, 'models');
    return _modelsDir!;
  }

  Future<List<InstalledModel>> getInstalledModels() async {
    final models = await getCatalogModels();
    final modelsDir = await getModelsDirectory();
    final results = <InstalledModel>[];

    for (final model in models) {
      final dir = p.join(modelsDir, model.installDirName);
      if (!await Directory(dir).exists()) {
        results.add(
          InstalledModel(voice: model, status: ModelStatus.notInstalled),
        );
        continue;
      }

      final status = await ModelFileValidator.getStatus(dir, model);
      results.add(
        InstalledModel(
          voice: model,
          status: status,
          modelDir: dir,
        ),
      );
    }

    return results;
  }

  Future<void> downloadModel(
    VoiceModel model, {
    void Function(double progress)? onProgress,
  }) async {
    final modelsDir = await getModelsDirectory();
    final tempDir = await getTemporaryDirectory();
    final archiveName = '${model.installDirName}.${model.archiveFormat}';
    final archivePath = p.join(tempDir.path, archiveName);
    final archiveFile = File(archivePath);
    final modelDir = Directory(p.join(modelsDir, model.installDirName));

    await Directory(modelsDir).create(recursive: true);

    try {
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }

      final request = http.Request('GET', Uri.parse(model.archiveUrl));
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Failed to download model: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = archiveFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(0.8 * receivedBytes / totalBytes);
        }
      }
      await sink.close();

      onProgress?.call(0.85);
      await ModelArchiveExtractor.extractArchive(
        archivePath: archivePath,
        archiveFormat: model.archiveFormat,
        outputDir: modelsDir,
      );

      final status = await ModelFileValidator.getStatus(modelDir.path, model);
      if (status != ModelStatus.ready) {
        final missing = await ModelFileValidator.missingEntries(
          modelDir.path,
          model,
        );
        throw Exception('Model extraction incomplete: ${missing.join(', ')}');
      }

      onProgress?.call(1.0);
    } finally {
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
    }
  }

  void dispose() {
    _client.close();
  }
}