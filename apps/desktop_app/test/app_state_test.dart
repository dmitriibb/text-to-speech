import 'package:desktop_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  test('registerExternalGeneratedAudio exposes OpenVoice output as a task', () {
    final state = AppState();
    addTearDown(state.dispose);

    state.registerExternalGeneratedAudio(
      label: 'openvoice-job-123',
      modelId: 'openvoice',
      modelName: 'OpenVoice',
      inputCharacterCount: 42,
      speechSpeed: 1.0,
      outputPath: '/tmp/openvoice-job-123.wav',
      startedAt: DateTime(2026, 4, 18, 10, 0, 0),
      finishedAt: DateTime(2026, 4, 18, 10, 0, 5),
    );

    expect(state.generatedWavPath, '/tmp/openvoice-job-123.wav');
    expect(state.synthesisStatus, SynthesisStatus.done);
    expect(state.taskManager.tasks, hasLength(1));
    expect(state.taskManager.tasks.single.type, LongRunningTaskType.synthesizeSpeech);
    expect(state.taskManager.tasks.single.modelName, 'OpenVoice');
    expect(state.taskManager.tasks.single.outputPath, '/tmp/openvoice-job-123.wav');
    expect(state.taskManager.tasks.single.hasPlayableAudio, isTrue);
  });
}
