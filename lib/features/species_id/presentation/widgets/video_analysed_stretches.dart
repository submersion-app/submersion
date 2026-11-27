import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
    required this.width,
  });

  final String mediaId;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // As the labels over a video (issue #4876): not where they never show.
    if (!marineLifeLabelsShown || !videoLabelsShown(defaultTargetPlatform)) {
      return const SizedBox.shrink();
    }
    final stretches = ref.watch(videoScanStretchesProvider(mediaId)).value;
    // Null too for a scan with no length, so there is always one here.
    if (stretches == null) return const SizedBox.shrink();
    final total = stretches.durationMs;
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
