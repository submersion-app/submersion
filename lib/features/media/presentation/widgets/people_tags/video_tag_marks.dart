import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';

/// Small marks on a video's scrub bar at each moment someone is tagged
/// (issue #1745). Laid over the bar's track, [width] wide; draws nothing
/// until the duration is known or when nobody is tagged at a moment.
class VideoTagMarks extends ConsumerWidget {
  final String mediaId;
  final Duration duration;
  final double width;

  const VideoTagMarks({
    super.key,
    required this.mediaId,
    required this.duration,
    required this.width,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = duration.inMilliseconds;
    if (total <= 0) return const SizedBox.shrink();
    final chips =
        ref.watch(mediaPeopleChipsProvider(mediaId)).value ?? const [];
    final moments = {
      for (final chip in chips)
        if (chip.tag.videoPosition != null) chip.tag.videoPosition!,
    };
    if (moments.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final at in moments)
              Positioned(
                left:
                    (width * (at.inMilliseconds / total).clamp(0.0, 1.0)) - 1.5,
                top: -3,
                child: Container(
                  width: 3,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
