import 'package:flutter/material.dart';

/// Scrubber + play/pause. Owns no state: the page owns the ValueNotifier
/// and the AnimationController so viewport, readout, and bar all observe
/// the same normalized position.
class TimeScrubBar extends StatelessWidget {
  final ValueNotifier<double> position;
  final bool playing;
  final VoidCallback onPlayPause;

  const TimeScrubBar({
    super.key,
    required this.position,
    required this.playing,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          onPressed: onPlayPause,
        ),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: position,
            builder: (context, value, _) => Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: (v) => position.value = v,
            ),
          ),
        ),
      ],
    );
  }
}
