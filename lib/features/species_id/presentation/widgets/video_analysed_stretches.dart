import 'package:flutter/material.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';

/// The stretches of a video the app has already looked at for marine life,
/// tinted along its scrub bar (issue #4825): the scan follows the
/// playhead, so they need not start at the beginning. Drawn only while the
/// scan is not finished; a finished video has a plain bar. Laid over the
/// bar's track, [width] wide, under the played part and the thumb.
class VideoAnalysedStretches extends ConsumerWidget {
  const VideoAnalysedStretches({
    super.key,
    required this.mediaId,
    required this.duration,
    required this.width,
  });

  final String mediaId;

  /// The video's length as the player has it, for a scan that has none.
  final Duration duration;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!marineLifeIdEnabled) return const SizedBox.shrink();
    final stretches = ref.watch(videoScanStretchesProvider(mediaId)).value;
    if (stretches == null) return const SizedBox.shrink();
    final total = stretches.durationMs > 0
        ? stretches.durationMs
        : duration.inMilliseconds;
    if (total <= 0) return const SizedBox.shrink();
    double at(int ms) => width * (ms / total).clamp(0.0, 1.0);
    final colour = Theme.of(context).colorScheme.tertiary;
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: 4,
        child: Stack(
          children: [
            for (final s in stretches.scanned.stretches)
              Positioned(
                key: ValueKey('video_analysed_${s.startMs}'),
                left: at(s.startMs),
                width: at(s.endMs) - at(s.startMs),
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
