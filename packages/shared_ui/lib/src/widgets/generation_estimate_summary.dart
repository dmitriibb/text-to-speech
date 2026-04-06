import 'package:flutter/material.dart';

class GenerationEstimateSummary extends StatelessWidget {
  const GenerationEstimateSummary({
    super.key,
    this.expectedGenerationDuration,
    this.expectedOutputDuration,
  });

  final Duration? expectedGenerationDuration;
  final Duration? expectedOutputDuration;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (expectedGenerationDuration != null)
        'Expected generation time: ${_formatDuration(expectedGenerationDuration!)}',
      if (expectedOutputDuration != null)
        'Expected audio length: ${_formatDuration(expectedOutputDuration!)}',
    ];

    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            Text(lines[i], style: textTheme.bodySmall),
            if (i < lines.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inMilliseconds <= 0
        ? 0
        : (duration.inMilliseconds / 1000).round();

    if (totalSeconds < 60) {
      return '$totalSeconds sec';
    }

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
