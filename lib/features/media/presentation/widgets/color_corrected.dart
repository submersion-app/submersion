import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

/// Draws [child] (an image of [item]) with the item's colour correction
/// (issue #3520): the hand adjustment, the automatic fix, or both, as one
/// colour matrix. Display-only: the pixels behind [child] are never changed.
///
/// [analysisSource] is the image [child] draws, used for the automatic
/// fix's colour statistics. A video tile uses its per-moment track's
/// average ([track], else [videoColorTrackProvider]), falling back to the
/// poster's own colour while the track is unknown.
class ColorCorrected extends ConsumerStatefulWidget {
  const ColorCorrected({
    super.key,
    required this.item,
    required this.analysisSource,
    required this.child,
    this.track,
  });

  final MediaItem item;
  final ImageProvider analysisSource;
  final Widget child;
  final VideoColorTrack? track;

  @override
  ConsumerState<ColorCorrected> createState() => _ColorCorrectedState();
}

class _ColorCorrectedState extends ConsumerState<ColorCorrected> {
  String? _requestedKey;

  /// Stats for [key], asking for them (once) when not analysed yet.
  ChannelStats? _stats(String key) {
    final service = ref.read(colorAnalysisServiceProvider);
    final cached = service.peek(key);
    if (cached != null || _requestedKey == key) return cached;
    _requestedKey = key;
    service.statsFor(key, widget.analysisSource).then((stats) {
      if (mounted && stats != null) setState(() {});
    });
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (ref.watch(colorPeekOriginalProvider) == item.id) return widget.child;

    final adjustment = effectiveAdjustment(ref, item);
    final onDive =
        item.diveId != null &&
        (item.mediaType == MediaType.photo ||
            item.mediaType == MediaType.video);
    final diverAuto = onDive && ref.watch(diverAutoColorCorrectionProvider);

    AutoCorrectionParams? auto;
    if (autoNeedFor(
          item,
          adjustment: adjustment,
          diverAutoEnabled: diverAuto,
        ) ==
        AutoNeed.stats) {
      final track = item.isVideo
          ? widget.track ??
                ref.watch(videoColorTrackProvider(VideoTrackKey(item))).value
          : null;
      auto = track != null
          ? track.average
          : autoParamsForPhoto(item, _stats(colorStatsKey(item)));
    }

    final matrix = composeCorrection(adjustment: adjustment, auto: auto);
    if (matrix.isIdentity) return widget.child;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix.values),
      child: widget.child,
    );
  }
}
