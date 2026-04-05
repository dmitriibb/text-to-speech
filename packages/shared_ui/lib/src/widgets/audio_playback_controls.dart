import 'package:flutter/material.dart';

class AudioPlaybackControls extends StatefulWidget {
  const AudioPlaybackControls({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onTogglePlayback,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.onSeek,
  });

  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final VoidCallback onTogglePlayback;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final ValueChanged<Duration>? onSeek;

  @override
  State<AudioPlaybackControls> createState() => _AudioPlaybackControlsState();
}

class _AudioPlaybackControlsState extends State<AudioPlaybackControls> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration ?? Duration.zero;
    final maxMillis = total.inMilliseconds > 0 ? total.inMilliseconds : 1;
    final sliderValue = _dragValue ??
        widget.position.inMilliseconds.clamp(0, maxMillis).toDouble();
    final currentMillis = sliderValue.round().clamp(0, maxMillis);
    final canSeek = widget.onSeek != null && total.inMilliseconds > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: widget.onTogglePlayback,
              icon: Icon(widget.isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(widget.isPlaying ? 'Stop' : 'Play'),
            ),
            if (widget.secondaryActionLabel != null) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: widget.onSecondaryAction,
                icon: const Icon(Icons.ios_share),
                label: Text(widget.secondaryActionLabel!),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider.adaptive(
                value: sliderValue,
                max: maxMillis.toDouble(),
                onChanged: canSeek
                    ? (value) {
                        setState(() {
                          _dragValue = value;
                        });
                      }
                    : null,
                onChangeEnd: canSeek
                    ? (value) {
                        setState(() {
                          _dragValue = null;
                        });
                        widget.onSeek!(
                          Duration(milliseconds: value.round()),
                        );
                      }
                    : null,
              ),
              Row(
                children: [
                  Text(
                    _format(
                      Duration(milliseconds: currentMillis),
                    ),
                  ),
                  const Spacer(),
                  Text(_format(total)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(Duration value) {
    final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
