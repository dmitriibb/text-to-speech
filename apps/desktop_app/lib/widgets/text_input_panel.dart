import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'package:shared_ui/shared_ui.dart';

/// Multi-line text input area for the text to synthesize.
class TextInputPanel extends StatefulWidget {
  const TextInputPanel({super.key});

  @override
  State<TextInputPanel> createState() => _TextInputPanelState();
}

class _TextInputPanelState extends State<TextInputPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      context.read<AppState>().setInputText(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _syncControllerText(state.inputText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: 8,
          minLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Type or paste English text here...',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            labelText: 'Text',
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _controller.clear,
                    tooltip: 'Clear text',
                  )
                : null,
          ),
        ),
        GenerationEstimateSummary(
          expectedGenerationDuration: state.expectedGenerationDuration,
          expectedOutputDuration: state.expectedOutputDuration,
        ),
      ],
    );
  }

  void _syncControllerText(String nextText) {
    if (_controller.text == nextText) {
      return;
    }

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }
}
