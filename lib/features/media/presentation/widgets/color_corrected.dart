import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

/// Draws [child] (an image of [item]) with the item's colour correction
/// (issue #3520): the hand adjustment, the automatic fix, or both, as one
/// colour matrix. Display-only: the pixels behind [child] are never changed.
///
/// [analysisSource] is the image [child] draws, used for the automatic
/// fix's colour statistics. A video tile uses its per-moment track's
/// average ([videoColorTrackProvider]), falling back to the
/// poster's own colour while the track is unknown.
class ColorCorrected extends ConsumerStatefulWidget {
  const ColorCorrected({
    super.key,
    required this.item,
    required this.analysisSource,
    required this.child,
  });

  final MediaItem item;

  /// Null while [child] is not yet a decoded frame of [item] itself.
  final ImageProvider? analysisSource;
  final Widget child;

  @override
  ConsumerState<ColorCorrected> createState() => _ColorCorrectedState();
}

class _ColorCorrectedState extends ConsumerState<ColorCorrected> {
  String? _requestedKey;

  /// The last stats this tile drew, and for which item.
  ({String id, ChannelStats stats})? _last;

  /// Stats for [key], asking for them when the service has no answer.
  ///
  /// Asked again after an eviction or a failed decode, which the service
  /// no longer knows; not while this tile's own request is under way or
  /// once the image proved to have no usable pixels.
  ChannelStats? _stats(String key) {
    final service = ref.read(colorAnalysisServiceProvider);
    final cached = service.peek(key);
    if (cached != null) {
      _last = (id: widget.item.id, stats: cached);
      return cached;
    }
    // Analysed, and too few usable pixels: nothing to correct with.
    if (service.hasAnswer(key)) return null;
    final source = widget.analysisSource;
    if (source != null && !(_requestedKey == key && service.isPending(key))) {
      _requestedKey = key;
      service.statsFor(key, source).then((stats) {
        if (mounted && stats != null) setState(() {});
      });
    }
    // While a new key for the same item is analysed (a relink, an upload
    // stamping the content hash), it keeps the colours it had rather than
    // flashing uncorrected.
    final last = _last;
    return last != null && last.id == widget.item.id ? last.stats : null;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (ref.watch(colorPeekOriginalNotifierProvider) == item.id) {
      return widget.child;
    }

    final adjustment = effectiveAdjustment(ref, item);
    final diverAuto = diverAutoFor(ref, item);

    // A dive photo or video read without its profile match (the library's
    // lean rows) gets it from the database before the automatic fix is
    // worked out, so its depth, surface check and (for a video) the depth
    // through the clip match the dive's own grid. No fix until it has
    // answered: guessing without depth could warm a surface shot.
    var placed = item;
    var placementKnown = true;
    if (needsStoredMatch(
      item,
      adjustment: adjustment,
      diverAutoEnabled: diverAuto,
    )) {
      final stored = ref.watch(colorEnrichmentProvider(item.id));
      placementKnown = stored.hasValue;
      placed = item.copyWith(enrichment: stored.value);
    }

    AutoCorrectionParams? auto;
    if (placementKnown &&
        needsAutoStats(
          placed,
          adjustment: adjustment,
          diverAutoEnabled: diverAuto,
        )) {
      final track = item.isVideo
          ? ref
                .watch(
                  // Only a file already on this device: a grid never
                  // fetches a whole video to colour its tile.
                  videoColorTrackProvider(
                    VideoTrackKey(placed, path: item.localPath),
                  ),
                )
                .value
          : null;
      auto = track != null
          ? track.average
          : autoParamsForPhoto(placed, _stats(colorStatsKey(item)));
    }

    final matrix = composeCorrection(adjustment: adjustment, auto: auto);
    if (matrix.isIdentity) return widget.child;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix.values),
      child: widget.child,
    );
  }
}
