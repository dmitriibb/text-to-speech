import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/cloned_voice.dart';
import '../services/open_voice_backend_service.dart';
import '../state/voice_lab_state.dart';
import '../widgets/app_navigation_drawer.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';

typedef OpenVoiceSampleFile = Future<String?> Function();

class VoiceSampleImportResult {
  const VoiceSampleImportResult({required this.name, required this.path});

  final String name;
  final String path;
}

class VoiceSampleImportDialog extends StatefulWidget {
  const VoiceSampleImportDialog({super.key, required this.openVoiceSampleFile});

  final OpenVoiceSampleFile openVoiceSampleFile;

  @override
  State<VoiceSampleImportDialog> createState() =>
      _VoiceSampleImportDialogState();
}

class _VoiceSampleImportDialogState extends State<VoiceSampleImportDialog> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  String _selectedPath = '';

  bool get _canImport =>
      _nameController.text.trim().isNotEmpty && _selectedPath.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Voice Sample'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Voice Name',
                hintText: 'e.g., "My Voice", "Narrator"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Selected Audio File',
                hintText: 'Choose a reference WAV or MP3 file',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose Audio File'),
            ),
            const SizedBox(height: 8),
            Text(
              'Use a 10–30 second mono WAV or MP3 clip of the voice you want to clone. MP3 files are converted to WAV automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canImport
              ? () => Navigator.of(context).pop(
                  VoiceSampleImportResult(
                    name: _nameController.text.trim(),
                    path: _selectedPath,
                  ),
                )
              : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Future<void> _chooseFile() async {
    final path = await widget.openVoiceSampleFile();
    if (!mounted || path == null) {
      return;
    }

    setState(() {
      _selectedPath = path;
      _pathController.text = path;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = p.basenameWithoutExtension(path);
      }
    });
  }
}

class VoiceLabScreen extends StatelessWidget {
  const VoiceLabScreen({
    super.key,
    this.openVoiceSampleFile,
    this.stateOverride,
  });

  final OpenVoiceSampleFile? openVoiceSampleFile;
  final VoiceLabState? stateOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.voiceLab,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Voice Lab'), centerTitle: false),
      body: VoiceLabPanel(
        openVoiceSampleFile: openVoiceSampleFile,
        stateOverride: stateOverride,
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
      case AppDestination.models:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const ModelsScreen()),
        );
      case AppDestination.voiceLab:
        break;
    }
  }
}

class VoiceLabPanel extends StatefulWidget {
  const VoiceLabPanel({
    super.key,
    this.openVoiceSampleFile,
    this.stateOverride,
  });

  final OpenVoiceSampleFile? openVoiceSampleFile;
  final VoiceLabState? stateOverride;

  @override
  State<VoiceLabPanel> createState() => _VoiceLabPanelState();
}

class _VoiceLabPanelState extends State<VoiceLabPanel> {
  late final VoiceLabState _state;
  late final TextEditingController _openVoiceUrlController;
  late final TextEditingController _omniVoiceUrlController;
  late final TextEditingController _omniVoiceLanguageController;
  late final TextEditingController _omniVoiceReferenceTextController;
  late final TextEditingController _omniVoiceInstructionController;
  late final TextEditingController _omniVoiceDurationController;
  late final TextEditingController _omniVoiceNumStepController;

  @override
  void initState() {
    super.initState();
    _state = widget.stateOverride ?? context.read<VoiceLabState>();
    _openVoiceUrlController = TextEditingController(
      text: _state.openVoiceBackendUrl,
    );
    _omniVoiceUrlController = TextEditingController(
      text: _state.omniVoiceBackendUrl,
    );
    _omniVoiceLanguageController = TextEditingController(
      text: _state.omniVoiceLanguage,
    );
    _omniVoiceReferenceTextController = TextEditingController(
      text: _state.omniVoiceReferenceText,
    );
    _omniVoiceInstructionController = TextEditingController(
      text: _state.omniVoiceInstruction,
    );
    _omniVoiceDurationController = TextEditingController(
      text: _state.omniVoiceDurationSeconds,
    );
    _omniVoiceNumStepController = TextEditingController(
      text: _state.omniVoiceNumStep,
    );
  }

  @override
  void dispose() {
    _openVoiceUrlController.dispose();
    _omniVoiceUrlController.dispose();
    _omniVoiceLanguageController.dispose();
    _omniVoiceReferenceTextController.dispose();
    _omniVoiceInstructionController.dispose();
    _omniVoiceDurationController.dispose();
    _omniVoiceNumStepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: Consumer<VoiceLabState>(
        builder: (context, state, _) {
          if (_openVoiceUrlController.text != state.openVoiceBackendUrl) {
            _openVoiceUrlController.value = TextEditingValue(
              text: state.openVoiceBackendUrl,
              selection: TextSelection.collapsed(
                offset: state.openVoiceBackendUrl.length,
              ),
            );
          }
          if (_omniVoiceUrlController.text != state.omniVoiceBackendUrl) {
            _omniVoiceUrlController.value = TextEditingValue(
              text: state.omniVoiceBackendUrl,
              selection: TextSelection.collapsed(
                offset: state.omniVoiceBackendUrl.length,
              ),
            );
          }
          _syncTextController(
            _omniVoiceLanguageController,
            state.omniVoiceLanguage,
          );
          _syncTextController(
            _omniVoiceReferenceTextController,
            state.omniVoiceReferenceText,
          );
          _syncTextController(
            _omniVoiceInstructionController,
            state.omniVoiceInstruction,
          );
          _syncTextController(
            _omniVoiceDurationController,
            state.omniVoiceDurationSeconds,
          );
          _syncTextController(
            _omniVoiceNumStepController,
            state.omniVoiceNumStep,
          );

          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildPocketTtsCard(context, state),
                const SizedBox(height: 16),
                _buildOpenVoiceCard(context, state),
                const SizedBox(height: 16),
                _buildOmniVoiceCard(context, state),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(context, state.errorMessage!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.science_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Advanced Functionality',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Desktop-only voice lab offers the built-in Pocket path, the OpenVoice cloning backend, and a broader OmniVoice multilingual backend with clone, preset, and auto-voice modes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPocketTtsCard(BuildContext context, VoiceLabState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              value: state.hasPocketModel && state.isPocketVoiceCloningEnabled,
              onChanged: state.hasPocketModel
                  ? state.setVoiceCloningEnabled
                  : null,
              secondary: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Voice cloning Pocket TTS'),
            ),
            if (state.isPocketVoiceCloningEnabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModelStatus(context, state),
                    const SizedBox(height: 16),
                    _buildImportSection(context, state),
                    const SizedBox(height: 16),
                    _buildVoiceLibrary(context, state),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpenVoiceCard(BuildContext context, VoiceLabState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              value: state.isOpenVoiceEnabled,
              onChanged: state.setOpenVoiceEnabled,
              secondary: const Icon(Icons.graphic_eq_outlined),
              title: const Text('Voice cloning OpenVoice'),
            ),
            if (state.isOpenVoiceEnabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildBackendSection(
                  context,
                  state,
                  connectionState: state.openVoiceConnectionState,
                  backendMessage: state.openVoiceBackendMessage,
                  backendUrlController: _openVoiceUrlController,
                  backendUrlChanged: state.setOpenVoiceBackendUrl,
                  checkConnection: () =>
                      state.checkOpenVoiceConnection(showAsError: true),
                  selectSample: () => _selectOpenVoiceSample(state),
                  samplePath: state.openVoiceSamplePath,
                  hasSharedInputText: state.hasSharedInputText,
                  canGenerate: state.canGenerateWithOpenVoice,
                  generate: state.generateWithOpenVoice,
                  isGenerating: state.isOpenVoiceGenerationSubmitting,
                  activeJobId: state.activeOpenVoiceJobId,
                  emptySampleText: 'No OpenVoice reference audio selected yet.',
                  emptyTextHint:
                      'Add text in the Basic panel before generating OpenVoice speech.',
                  latestJobLabel: 'Latest OpenVoice job',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOmniVoiceCard(BuildContext context, VoiceLabState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              value: state.isOmniVoiceEnabled,
              onChanged: state.setOmniVoiceEnabled,
              secondary: const Icon(Icons.multitrack_audio_outlined),
              title: const Text('OmniVoice Multilingual TTS'),
            ),
            if (state.isOmniVoiceEnabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildBackendSection(
                  context,
                  state,
                  connectionState: state.omniVoiceConnectionState,
                  backendMessage: state.omniVoiceBackendMessage,
                  backendUrlController: _omniVoiceUrlController,
                  backendUrlChanged: state.setOmniVoiceBackendUrl,
                  checkConnection: () =>
                      state.checkOmniVoiceConnection(showAsError: true),
                  descriptionText:
                      'Advanced multilingual OmniVoice backend with clone-from-reference, preset voice design, and auto voice generation modes.',
                  extraContent: _buildOmniVoiceExtraControls(context, state),
                  showSamplePicker: state.omniVoiceRequiresReferenceAudio,
                  selectSample: () => _selectOmniVoiceSample(state),
                  selectSampleLabel: 'Select Reference Audio',
                  samplePath: state.omniVoiceSamplePath,
                  hasSharedInputText: state.hasSharedInputText,
                  canGenerate: state.canGenerateWithOmniVoice,
                  generate: state.generateWithOmniVoice,
                  isGenerating: state.isOmniVoiceGenerationSubmitting,
                  activeJobId: state.activeOmniVoiceJobId,
                  emptySampleText: 'No OmniVoice reference audio selected yet.',
                  emptyTextHint:
                      'Add text in the Basic panel before generating OmniVoice speech.',
                  latestJobLabel: 'Latest OmniVoice job',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatus(BuildContext context, VoiceLabState state) {
    if (state.hasPocketModel) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pocket TTS model is ready for voice cloning.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pocket TTS model not installed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Install the Pocket TTS model from the model catalog on the main screen to enable voice cloning.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context, VoiceLabState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Voice Sample',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Provide a short WAV or MP3 audio clip (10–30 seconds) of the voice you want to clone. MP3 files are converted to WAV automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _showImportDialog(context, state),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import Audio File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceLibrary(BuildContext context, VoiceLabState state) {
    if (state.voices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No cloned voices yet. Import a voice sample to get started.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voice Library', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...state.voices.map((voice) => _buildVoiceCard(context, state, voice)),
      ],
    );
  }

  Widget _buildBackendSection(
    BuildContext context,
    VoiceLabState state, {
    required OpenVoiceBackendConnectionState connectionState,
    required String? backendMessage,
    required TextEditingController backendUrlController,
    required ValueChanged<String> backendUrlChanged,
    required VoidCallback checkConnection,
    String descriptionText =
        'Advanced path through a manually started local backend. This MVP accepts a WAV or MP3 reference sample, converts MP3 to WAV automatically, and uses async job polling.',
    Widget? extraContent,
    bool showSamplePicker = true,
    VoidCallback? selectSample,
    String selectSampleLabel = 'Select Reference Audio',
    String? samplePath,
    required bool hasSharedInputText,
    required bool canGenerate,
    required Future<void> Function() generate,
    required bool isGenerating,
    required String? activeJobId,
    String emptySampleText = '',
    required String emptyTextHint,
    required String latestJobLabel,
  }) {
    final (statusEmoji, statusText, statusColor) = switch (connectionState) {
      OpenVoiceBackendConnectionState.connected => (
        '✅',
        'Backend OK',
        Theme.of(context).colorScheme.primary,
      ),
      OpenVoiceBackendConnectionState.checking => (
        '⏳',
        'Checking',
        Theme.of(context).colorScheme.tertiary,
      ),
      OpenVoiceBackendConnectionState.error => (
        '❌',
        'Backend Down',
        Theme.of(context).colorScheme.error,
      ),
      OpenVoiceBackendConnectionState.disconnected => (
        '⚪',
        'Not Checked',
        Theme.of(context).colorScheme.outline,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(descriptionText, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(statusEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                backendMessage ??
                    'Check the backend connection before generating speech.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: backendUrlController,
          onChanged: (value) {
            backendUrlChanged(value);
          },
          decoration: const InputDecoration(
            labelText: 'Backend URL',
            hintText: 'http://127.0.0.1:8008',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed:
                  connectionState == OpenVoiceBackendConnectionState.checking
                  ? null
                  : checkConnection,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Check Connection'),
            ),
            if (showSamplePicker && selectSample != null)
              OutlinedButton.icon(
                onPressed: selectSample,
                icon: const Icon(Icons.audio_file_outlined),
                label: Text(selectSampleLabel),
              ),
          ],
        ),
        if (extraContent != null) ...[const SizedBox(height: 16), extraContent],
        if (showSamplePicker) ...[
          const SizedBox(height: 12),
          Text(
            samplePath ?? emptySampleText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          hasSharedInputText
              ? 'Speech generation uses the text currently entered in the Basic panel.'
              : emptyTextHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canGenerate ? generate : null,
            icon: Icon(isGenerating ? Icons.sync : Icons.graphic_eq),
            label: Text(isGenerating ? 'Generating...' : 'Generate Speech'),
          ),
        ),
        if (activeJobId case final jobId?) ...[
          const SizedBox(height: 8),
          Text(
            '$latestJobLabel: $jobId',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOmniVoiceExtraControls(
    BuildContext context,
    VoiceLabState state,
  ) {
    final selectedVoice = state.selectedOmniVoice;
    final featureLabels = <String>[
      if (state.omniVoiceSupportsNonVerbalTokens) 'Non-verbal tags',
      if (state.omniVoiceSupportsPronunciationControl) 'Pronunciation control',
      if (state.omniVoiceSupportsReferenceText) 'Reference transcript',
      if (state.omniVoiceSupportsDuration) 'Duration override',
      if (state.omniVoiceSupportsNumStep) 'Diffusion steps',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.omniVoiceEngineDisplayName != null) ...[
          Text(
            state.omniVoiceEngineDisplayName!,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(
          value: state.selectedOmniVoiceId,
          decoration: const InputDecoration(
            labelText: 'OmniVoice voice',
            border: OutlineInputBorder(),
          ),
          items: state.omniVoiceVoices
              .map(
                (voice) => DropdownMenuItem<String>(
                  value: voice.id,
                  child: Text(voice.displayName),
                ),
              )
              .toList(growable: false),
          onChanged: state.setSelectedOmniVoiceId,
        ),
        const SizedBox(height: 8),
        Text(
          selectedVoice.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _omniVoiceLanguageController,
          onChanged: state.setOmniVoiceLanguage,
          decoration: const InputDecoration(
            labelText: 'Target language',
            hintText: 'en, fr, uk, ja, ar...',
            border: OutlineInputBorder(),
          ),
        ),
        if (state.omniVoiceSupportsInstruction) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _omniVoiceInstructionController,
            onChanged: state.setOmniVoiceInstruction,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Voice instruction',
              hintText: 'female, low pitch, british accent',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (state.omniVoiceSupportsReferenceText) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _omniVoiceReferenceTextController,
            onChanged: state.setOmniVoiceReferenceText,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reference transcript (optional)',
              hintText:
                  'Leave blank to let OmniVoice transcribe automatically.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (state.omniVoiceSupportsDuration ||
            state.omniVoiceSupportsNumStep) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (state.omniVoiceSupportsDuration)
                Expanded(
                  child: TextField(
                    controller: _omniVoiceDurationController,
                    onChanged: state.setOmniVoiceDurationSeconds,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Duration (seconds)',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              if (state.omniVoiceSupportsDuration &&
                  state.omniVoiceSupportsNumStep)
                const SizedBox(width: 12),
              if (state.omniVoiceSupportsNumStep)
                Expanded(
                  child: TextField(
                    controller: _omniVoiceNumStepController,
                    onChanged: state.setOmniVoiceNumStep,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Diffusion steps',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (featureLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: featureLabels
                .map((label) => Chip(label: Text(label)))
                .toList(growable: false),
          ),
        ],
        if (state.omniVoiceSupportsNonVerbalTokens ||
            state.omniVoiceSupportsPronunciationControl) ...[
          const SizedBox(height: 12),
          Text(
            'OmniVoice can also follow inline controls in the shared Basic text, such as `[laughter]` tags and pronunciation hints.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  void _syncTextController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Widget _buildVoiceCard(
    BuildContext context,
    VoiceLabState state,
    ClonedVoice voice,
  ) {
    final isPreviewing =
        state.previewingVoiceId == voice.id && state.isPreviewPlaying;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Created ${_formatDate(voice.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // Preview button
                IconButton(
                  onPressed: isPreviewing
                      ? () => state.stopPreview()
                      : () => state.previewVoice(voice),
                  icon: Icon(isPreviewing ? Icons.stop : Icons.play_arrow),
                  tooltip: isPreviewing ? 'Stop preview' : 'Preview reference',
                ),
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(context, state, voice),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete voice',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.hasSharedInputText
                  ? 'Uses the text currently entered in the Basic panel.'
                  : 'Add text in the Basic panel before generating cloned speech.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    state.hasPocketModel &&
                        state.isPocketVoiceCloningEnabled &&
                        state.hasSharedInputText
                    ? () => state.generateWithClonedVoice(voice: voice)
                    : null,
                icon: const Icon(Icons.record_voice_over, size: 18),
                label: const Text('Generate With Cloned Voice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }

  Future<void> _showImportDialog(
    BuildContext context,
    VoiceLabState state,
  ) async {
    final result = await showDialog<VoiceSampleImportResult>(
      context: context,
      builder: (context) =>
          VoiceSampleImportDialog(openVoiceSampleFile: _pickVoiceSampleFile),
    );

    if (result == null) {
      return;
    }

    if (!File(result.path).existsSync()) {
      state.setError('File not found: ${result.path}');
      return;
    }

    await state.addVoice(name: result.name, audioPath: result.path);
  }

  Future<String?> _pickVoiceSampleFile() async {
    if (widget.openVoiceSampleFile case final openVoiceSampleFile?) {
      return openVoiceSampleFile();
    }

    const audioTypeGroup = XTypeGroup(
      label: 'Audio samples',
      extensions: ['wav', 'mp3'],
      mimeTypes: ['audio/wav', 'audio/x-wav', 'audio/mpeg', 'audio/mp3'],
    );
    final selectedFile = await openFile(
      acceptedTypeGroups: const [audioTypeGroup],
      confirmButtonText: 'Select voice sample',
    );
    return selectedFile?.path;
  }

  Future<String?> _pickOpenVoiceSampleFile() async {
    if (widget.openVoiceSampleFile case final openVoiceSampleFile?) {
      return openVoiceSampleFile();
    }

    const audioTypeGroup = XTypeGroup(
      label: 'Audio samples',
      extensions: ['wav', 'mp3'],
      mimeTypes: ['audio/wav', 'audio/x-wav', 'audio/mpeg', 'audio/mp3'],
    );
    final selectedFile = await openFile(
      acceptedTypeGroups: const [audioTypeGroup],
      confirmButtonText: 'Select backend reference audio',
    );
    return selectedFile?.path;
  }

  Future<void> _selectOpenVoiceSample(VoiceLabState state) async {
    final path = await _pickOpenVoiceSampleFile();
    if (path == null) {
      return;
    }
    if (!File(path).existsSync()) {
      state.setError('File not found: $path');
      return;
    }
    state.setOpenVoiceSamplePath(path);
  }

  Future<void> _selectOmniVoiceSample(VoiceLabState state) async {
    final path = await _pickOpenVoiceSampleFile();
    if (path == null) {
      return;
    }
    if (!File(path).existsSync()) {
      state.setError('File not found: $path');
      return;
    }
    state.setOmniVoiceSamplePath(path);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    VoiceLabState state,
    ClonedVoice voice,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voice'),
        content: Text('Remove "${voice.name}" from the voice library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await state.removeVoice(voice.id);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
