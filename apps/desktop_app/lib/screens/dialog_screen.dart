import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';
import 'voice_lab_screen.dart';

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
                  readyModels: state.readyModels,
                  speakerSettings: state.dialogSpeakerSettings,
                  isGenerating: state.isDialogGenerating,
                  isSequencePlaying: state.isDialogPlaying,
                  activeLineId: state.activeDialogLineId,
                  errorMessage: state.dialogErrorMessage,
                  onPasteFromClipboard: state.pasteDialogFromClipboard,
                  onGenerate: state.generateDialog,
                  onPlayPauseSequence: state.playPauseDialog,
                  onStopSequence: state.stopDialogPlayback,
                  onPlayLine: state.playDialogLine,
                  onRemoveLine: state.removeDialogLine,
                  onModelSelected: state.setDialogSpeakerModel,
                  onSpeakerSelected: state.setDialogSpeakerVoice,
                  onLanguageSelected: state.setDialogSpeakerLanguage,
                  onVolumeChanged: state.setDialogSpeakerVolume,
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
          MaterialPageRoute<void>(builder: (context) => const VoiceLabScreen()),
        );
    }
  }
}
