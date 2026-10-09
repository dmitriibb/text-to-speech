import 'voice_model.dart';

enum SynthesisTargetKind { local, backend }

/// Backend identity is independent of ONNX installation paths and file checks.
class SynthesisTarget {
  const SynthesisTarget.local(this.modelId)
    : kind = SynthesisTargetKind.local,
      backendId = null;

  const SynthesisTarget.backend({
    required this.modelId,
    required this.backendId,
  }) : kind = SynthesisTargetKind.backend;

  final String modelId;
  final SynthesisTargetKind kind;
  final String? backendId;

  // Existing local IDs retain their settings keys.
  String get settingsKey => kind == SynthesisTargetKind.local
      ? modelId
      : 'backend:$backendId:$modelId';

  bool isLocalReady(InstalledModel model) =>
      kind == SynthesisTargetKind.local &&
      model.voice.id == modelId &&
      model.status == ModelStatus.ready &&
      (model.modelDir?.isNotEmpty ?? false);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'modelId': modelId,
    if (backendId != null) 'backendId': backendId,
  };

  factory SynthesisTarget.fromJson(Map<String, Object?> json) {
    final modelId = json['modelId'] as String?;
    if (modelId == null || modelId.trim().isEmpty) {
      throw const FormatException('Synthesis target requires a model ID.');
    }
    switch (json['kind']) {
      case 'local':
        return SynthesisTarget.local(modelId);
      case 'backend':
        final backendId = json['backendId'] as String?;
        if (backendId == null || backendId.trim().isEmpty) {
          throw const FormatException('Backend target requires a backend ID.');
        }
        return SynthesisTarget.backend(modelId: modelId, backendId: backendId);
      default:
        throw const FormatException('Unknown synthesis target kind.');
    }
  }
}

/// A health response must refer to this endpoint's selected model. Reachability
/// alone is insufficient; a loadable engine may still need its first load.
enum BackendReadiness { unavailable, reachable, loadable, loaded }

class BackendTargetStatus {
  const BackendTargetStatus({
    required this.target,
    required this.endpoint,
    required this.readiness,
    this.message,
  });

  final SynthesisTarget target;
  final Uri endpoint;
  final BackendReadiness readiness;
  final String? message;

  bool get canGenerate =>
      target.kind == SynthesisTargetKind.backend &&
      (readiness == BackendReadiness.loadable ||
          readiness == BackendReadiness.loaded);
}

/// Persist metadata only. Reference bytes belong in project-managed storage and
/// are uploaded by the desktop adapter, never passed as a remote host path.
class DialogReferenceAsset {
  DialogReferenceAsset({
    required this.relativePath,
    required this.sha256,
    required this.transcript,
  }) {
    if (relativePath.isEmpty ||
        relativePath.contains('\\') ||
        relativePath.contains(':') ||
        relativePath
            .split('/')
            .any((part) => part.isEmpty || part == '..' || part == '.')) {
      throw ArgumentError('Reference path must be relative to the project.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw ArgumentError('Reference requires a lowercase SHA-256 hash.');
    }
  }

  final String relativePath;
  final String sha256;
  final String transcript;

  Map<String, Object?> toJson() => {
    'relativePath': relativePath,
    'sha256': sha256,
    'transcript': transcript,
  };

  factory DialogReferenceAsset.fromJson(Map<String, Object?> json) =>
      DialogReferenceAsset(
        relativePath: json['relativePath'] as String,
        sha256: json['sha256'] as String,
        transcript: json['transcript'] as String,
      );
}
