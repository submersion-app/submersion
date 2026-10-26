import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/color_timeline_sampler.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

final _log = LoggerService.forClass(VideoTrackKey);

ColorAdjustment? _adjustmentOf(WidgetRef ref, MediaItem item) =>
    ref.read(colorAdjustmentDraftNotifierProvider(item.id)) ??
    item.colorAdjustment;

bool _diverAutoOf(WidgetRef ref, MediaItem item) =>
    isAutoCorrectable(item) && ref.read(diverAutoColorCorrectionProvider);

/// Whether sharing [item] may mean re-encoding it with a colour correction
/// (issue #3521): a video with sliders set or the automatic fix on. Cheap,
/// so the share flow can choose its progress dialog before working out the
/// correction itself, which may still turn out to be none.
bool videoMayNeedCorrection(WidgetRef ref, MediaItem item) {
  if (!item.isVideo) return false;
  final adjustment = _adjustmentOf(ref, item);
  if (adjustment != null && !adjustment.isNeutral) return true;
  return autoEnabledFor(
    item,
    adjustment: adjustment,
    diverAutoEnabled: _diverAutoOf(ref, item),
  );
}

/// The colour timeline a shared copy of the video [item] carries (issue
/// #3521): what the viewer draws it with at each moment, from the file at
/// [path]. Null when nothing would change, so the original is shared.
///
/// Mirrors `VideoColorFilter`: the live slider draft or the stored
/// adjustment, and the automatic fix from the clip's frame track bounded
/// by the dive profile, or the poster's colour when no track can be built.
Future<ColorTimeline?> videoShareTimelineFor(
  WidgetRef ref,
  MediaItem item, {
  required String? path,
}) async {
  if (!item.isVideo) return null;
  final adjustment = _adjustmentOf(ref, item);
  final diverAuto = _diverAutoOf(ref, item);
  final duration = item.durationSeconds?.toDouble();
  // A row shared from the library comes without its profile match; read
  // it so the copy gets the same depth and surface check as the viewer.
  var placed = item;
  if (needsStoredMatch(
    item,
    adjustment: adjustment,
    diverAutoEnabled: diverAuto,
  )) {
    placed = item.copyWith(
      enrichment: await ref
          .read(mediaColorAdjustmentRepositoryProvider)
          .enrichmentFor(item.id),
    );
  }
  if (!needsAutoStats(
    placed,
    adjustment: adjustment,
    diverAutoEnabled: diverAuto,
  )) {
    final matrix = composeCorrection(adjustment: adjustment);
    return sampleColorTimeline(
      durationSeconds: duration,
      matrixAt: (_) => matrix,
    );
  }

  final key = VideoTrackKey(placed, path: path);
  final track = await _readOnce<VideoColorTrack?>(
    ref,
    videoColorTrackProvider(key).future,
  );
  if (track != null) {
    final depthAt = await _readOnce<double? Function(double)?>(
      ref,
      videoDepthAtProvider(key).future,
    );
    return sampleColorTimeline(
      durationSeconds: duration,
      matrixAt: (s) => composeCorrection(
        adjustment: adjustment,
        auto: track.paramsAt(s, depthAt: depthAt),
      ),
    );
  }
  final matrix = composeCorrection(
    adjustment: adjustment,
    auto: autoParamsForPhoto(placed, await _posterStats(ref, placed)),
  );
  return sampleColorTimeline(
    durationSeconds: duration,
    matrixAt: (_) => matrix,
  );
}

/// The poster's colour: what a tile already measured, else the gallery
/// thumbnail measured now. Null when neither is available.
Future<ChannelStats?> _posterStats(WidgetRef ref, MediaItem item) async {
  final analysis = ref.read(colorAnalysisServiceProvider);
  final statsKey = colorStatsKey(item);
  final cached = analysis.peek(statsKey);
  if (cached != null) return cached;
  final poster = await _readOnce(ref, resolvedThumbnailProvider(item).future);
  final bytes = poster?.bytes;
  if (bytes == null) return null;
  return analysis.statsFor(statsKey, MemoryImage(bytes));
}

/// Reads an auto-disposing provider's value once, holding a listener so it
/// is not disposed mid-await. Null when it fails: the share then falls
/// back as the viewer would.
Future<T?> _readOnce<T>(
  WidgetRef ref,
  ProviderListenable<Future<T>> provider,
) async {
  final sub = ref.listenManual(provider, (_, _) {});
  try {
    return await sub.read();
  } on Object catch (e, stackTrace) {
    _log.warning(
      'Working out a shared video\'s colour failed',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  } finally {
    sub.close();
  }
}
