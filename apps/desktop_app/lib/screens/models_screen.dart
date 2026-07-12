import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import 'dialog_screen.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'backend_models_screen.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.models,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Models')),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.isLoadingModels) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ModelManagementPanel(
                  models: state.installedModels,
                  isDownloading: state.isDownloading,
                  currentInstallProgress: state.currentInstallProgress,
                  canManageModels: state.canManageModels,
                  onRefresh: state.refreshModels,
                  onInstall: state.downloadModel,
                  onDelete: state.deleteModel,
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
    Navigator.of(context).pop();

    switch (destination) {
      case AppDestination.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
      case AppDestination.liveTts:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const LiveTtsScreen()),
        );
      case AppDestination.dialog:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const DialogScreen()),
        );
      case AppDestination.models:
        break;
      case AppDestination.voiceLab:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => const BackendModelsScreen(),
          ),
        );
    }
  }
}
