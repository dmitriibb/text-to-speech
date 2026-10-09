import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../services/audio_service.dart';
import '../state/voice_lab_state.dart';
import '../services/dialog_backend_adapter.dart';
import '../widgets/dialog_backend_settings.dart';
import '../widgets/app_navigation_drawer.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';
import 'backend_models_screen.dart';

class DialogScreen extends StatelessWidget {
  const DialogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.dialog,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Dialog'), centerTitle: false),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final backends = context.watch<VoiceLabState>();
          if (state.isLoadingModels) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: DialogModePanel(
                  lines: state.dialogLines,
                  workspace: state.dialog,
                  masterIsPlaying:
                      state.generatedWavPath == state.dialog.masterPath &&
                      state.playbackState == PlaybackState.playing,
                  masterPosition:
                      state.generatedWavPath == state.dialog.masterPath
                      ? state.playbackPosition
                      : Duration.zero,
                  masterDuration:
                      state.generatedWavPath == state.dialog.masterPath
                      ? state.playbackDuration
                      : null,
                  onSeekMaster:
                      state.generatedWavPath == state.dialog.masterPath
                      ? state.seekPlayback
                      : null,
                  onRetryLine: state.retryDialogLine,
                  onRenderConversation: state.renderDialogConversation,
                  onPreviewConversation: state.previewDialogConversation,
                  onExportConversation: state.exportDialogConversation,
                  readyModels: [
                    ...state.readyModels,
                    if (backends.isVoxCpm2Enabled ||
                        state.dialog.actors.values.any(
                          (actor) =>
                              actor.effectiveTarget?.backendId == 'voxcpm2',
                        ))
                      voxCpm2DialogModel,
                  ],
                  extensionBuilderForSpeaker: (speaker) =>
                      (context, model, settings, onChanged) =>
                          model.voice.runtime == 'voxcpm2'
                          ? DialogBackendSettings(
                              workspace: state.dialog,
                              settings:
                                  settings.extensionValues['referenceAsset'] !=
                                          null ||
                                      state.dialog.actors[speaker]?.reference ==
                                          null
                                  ? settings
                                  : settings.copyWith(
                                      extensionValues: {
                                        ...settings.extensionValues,
                                        'referenceAsset': state
                                            .dialog
                                            .actors[speaker]!
                                            .reference!
                                            .toJson(),
                                      },
                                    ),
                              onChanged: onChanged,
                            )
                          : const SizedBox.shrink(),
                  speakerSettings: state.dialogSpeakerSettings,
                  isGenerating: state.isDialogGenerating,
                  isSequencePlaying: state.isDialogPlaying,
                  activeLineId: state.activeDialogLineId,
                  errorMessage: state.dialogErrorMessage,
                  importIssues: state.dialogImportIssues,
                  onPasteFromClipboard: state.pasteDialogFromClipboard,
                  onGenerate: state.generateDialog,
                  onPlayPauseSequence: state.playPauseDialog,
                  onStopSequence: state.stopDialogPlayback,
                  onPlayLine: state.playDialogLine,
                  onRemoveLine: state.removeDialogLine,
                  onModelSelected: state.setDialogSpeakerModel,
                  onSettingsChanged: state.setDialogSpeakerSettings,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToDestination(
    BuildContext context,
    AppDestination destination,
  ) {
    final state = context.read<AppState>();
    Navigator.of(context).pop();

    switch (destination) {
      case AppDestination.home:
        state.stopDialogPlayback();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
      case AppDestination.liveTts:
        state.stopDialogPlayback();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const LiveTtsScreen()),
        );
      case AppDestination.dialog:
        break;
      case AppDestination.models:
        state.stopDialogPlayback();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const ModelsScreen()),
        );
      case AppDestination.voiceLab:
        state.stopDialogPlayback();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => const BackendModelsScreen(),
          ),
        );
    }
  }
}
