import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import 'about_screen.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';
import 'settings_screen.dart';

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
      appBar: AppBar(title: const Text('Dialog')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F1E8), Color(0xFFE9F3F0)],
          ),
        ),
        child: Consumer<AppState>(
          builder: (context, state, _) {
            if (state.isLoadingModels) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
              ),
            );
          },
        ),
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
      case AppDestination.settings:
        state.stopDialogPlayback();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
        );
      case AppDestination.about:
        state.stopDialogPlayback();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
        );
    }
  }
}
