import 'dart:io';

import 'package:path/path.dart' as p;

import 'open_voice_backend_service.dart';

class OpenVoicePreferencesService {
  static const _backendUrlFile = '.tts_open_voice_backend_url';

  Future<String> loadBackendUrl() async {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) {
        return OpenVoiceBackendService.defaultBaseUrl;
      }

      final file = File(p.join(home, _backendUrlFile));
      if (!await file.exists()) {
        return OpenVoiceBackendService.defaultBaseUrl;
      }

      final saved = (await file.readAsString()).trim();
      return saved.isEmpty ? OpenVoiceBackendService.defaultBaseUrl : saved;
    } catch (_) {
      return OpenVoiceBackendService.defaultBaseUrl;
    }
  }

  Future<void> saveBackendUrl(String backendUrl) async {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) {
        return;
      }

      final file = File(p.join(home, _backendUrlFile));
      await file.writeAsString(backendUrl.trim(), flush: true);
    } catch (_) {}
  }
}