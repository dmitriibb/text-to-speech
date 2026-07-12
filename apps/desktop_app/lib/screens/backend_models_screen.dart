import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/voice_lab_state.dart';
import '../widgets/app_navigation_drawer.dart';
import 'dialog_screen.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';

/// Desktop-only connection settings for external model backends.
class BackendModelsScreen extends StatelessWidget {
  const BackendModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.voiceLab,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Backend models'), centerTitle: false),
      body: Consumer<VoiceLabState>(
        builder: (context, state, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Enable external model servers and configure their connection URLs. Voice and generation options are selected from each model’s settings dialog.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _BackendCard(
              title: 'OpenVoice',
              enabled: state.isOpenVoiceEnabled,
              backendUrl: state.openVoiceBackendUrl,
              status: state.openVoiceBackendMessage,
              onEnabledChanged: state.setOpenVoiceEnabled,
              onUrlSubmitted: state.setOpenVoiceBackendUrl,
              onCheckConnection: state.checkOpenVoiceConnection,
            ),
            const SizedBox(height: 16),
            _BackendCard(
              title: 'OmniVoice',
              enabled: state.isOmniVoiceEnabled,
              backendUrl: state.omniVoiceBackendUrl,
              status: state.omniVoiceBackendMessage,
              onEnabledChanged: state.setOmniVoiceEnabled,
              onUrlSubmitted: state.setOmniVoiceBackendUrl,
              onCheckConnection: state.checkOmniVoiceConnection,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDestination(
    BuildContext context,
    AppDestination destination,
  ) {
    Navigator.of(context).pop();
    final Widget? screen = switch (destination) {
      AppDestination.home => const HomeScreen(),
      AppDestination.liveTts => const LiveTtsScreen(),
      AppDestination.dialog => const DialogScreen(),
      AppDestination.models => const ModelsScreen(),
      AppDestination.voiceLab => null,
    };
    if (screen != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
    }
  }
}

class _BackendCard extends StatefulWidget {
  const _BackendCard({
    required this.title,
    required this.enabled,
    required this.backendUrl,
    required this.status,
    required this.onEnabledChanged,
    required this.onUrlSubmitted,
    required this.onCheckConnection,
  });

  final String title;
  final bool enabled;
  final String backendUrl;
  final String? status;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onUrlSubmitted;
  final VoidCallback onCheckConnection;

  @override
  State<_BackendCard> createState() => _BackendCardState();
}

class _BackendCardState extends State<_BackendCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.backendUrl);
  }

  @override
  void didUpdateWidget(covariant _BackendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backendUrl != oldWidget.backendUrl &&
        _controller.text != widget.backendUrl) {
      _controller.text = widget.backendUrl;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.title),
              subtitle: const Text('Use this backend model server'),
              value: widget.enabled,
              onChanged: widget.onEnabledChanged,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
              ),
              onSubmitted: widget.onUrlSubmitted,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.enabled
                      ? () {
                          widget.onUrlSubmitted(_controller.text.trim());
                          widget.onCheckConnection();
                        }
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check connection'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.status ?? 'Not checked')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
