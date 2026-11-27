import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/presentation/providers/video_sighting_providers.dart';

/// Bands on a video's scrub bar over each stretch in which a species was
/// seen (issue #5084), in the viewer opened from a sighting row. Laid over
/// the bar's 4 px track, [width] wide; draws nothing until the duration is
/// known or when the species has no timed sighting (a tag made by hand).
class VideoSightingMarks extends ConsumerWidget {
  const VideoSightingMarks({
    super.key,
    required this.mediaId,
    required this.speciesId,
    required this.duration,
    required this.width,
  });

  final String mediaId;
  final String speciesId;
  final Duration duration;
  final double width;

  /// The narrowest band, so a sighting of a moment still shows on a long
  /// video.
  static const double minWidth = 3;

  /// Legible on the black controls and apart from the white progress and
  /// the amber face-tag marks.
  static const Color color = Colors.tealAccent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = duration.inMilliseconds;
    if (total <= 0) return const SizedBox.shrink();
    final stretches =
        ref
            .watch(
              videoSpeciesSightingsProvider((
                mediaId: mediaId,
                speciesId: speciesId,
              )),
            )
            .value ??
        const [];
    if (stretches.isEmpty) return const SizedBox.shrink();
    double at(int ms) => width * (ms / total).clamp(0.0, 1.0);
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final s in stretches)
              Positioned(
                left: math.min(at(s.startMs), width - minWidth),
                top: 0,
                child: Container(
                  key: ValueKey('videoSightingMark_${s.startMs}'),
                  width: math.max(minWidth, at(s.endMs) - at(s.startMs)),
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
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
