import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

/// Draws a playing video ([child]) with its colour correction (issue #3520):
/// the automatic part follows the clip moment by moment (the frame track,
/// bounded by the dive profile's depth), and the hand sliders shift the
/// whole clip. Display-only: the video file is never touched.
///
/// [player] is the video's controller (any listenable of its value), read
/// for the playback position.
class VideoColorFilter extends ConsumerWidget {
  const VideoColorFilter({
    super.key,
    required this.item,
    required this.player,
    required this.child,
    this.path,
  });

  final MediaItem item;

  /// The file being played, which the frames are read from.
  final String? path;
  final ValueListenable<VideoPlayerValue> player;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(colorPeekOriginalNotifierProvider) == item.id) return child;
    final adjustment = effectiveAdjustment(ref, item);
    final diverAuto = diverAutoFor(ref, item);
    final needsAuto = needsAutoStats(
      item,
      adjustment: adjustment,
      diverAutoEnabled: diverAuto,
    );

    final key = VideoTrackKey(item, path: path);
    final track = needsAuto
        ? ref.watch(videoColorTrackProvider(key)).value
        : null;
    final depthAt = needsAuto
        ? ref.watch(videoDepthAtProvider(key)).value
        : null;
    // Before the track is known, the poster's colour (if a tile analysed it).
    final poster = needsAuto && track == null
        ? autoParamsForPhoto(
            item,
            ref.read(colorAnalysisServiceProvider).peek(colorStatsKey(item)),
          )
        : null;

    if (track == null) {
      return _filtered(composeCorrection(adjustment: adjustment, auto: poster));
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      child: child,
      builder: (context, value, child) {
        final seconds =
            value.position.inMicroseconds / Duration.microsecondsPerSecond;
        final AutoCorrectionParams auto = track.paramsAt(
          seconds,
          depthAt: depthAt,
        );
        return _filtered(
          composeCorrection(adjustment: adjustment, auto: auto),
          child: child,
        );
      },
    );
  }

  Widget _filtered(ColorMatrix matrix, {Widget? child}) {
    final shown = child ?? this.child;
    if (matrix.isIdentity) return shown;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix.values),
      child: shown,
    );
  }
}
