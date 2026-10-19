import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

final _log = LoggerService.forClass(VideoTrackKey);

/// The platform's video engine (frame extraction lives beside transcoding).
final transcodeEngineProvider = Provider<TranscodeEngine?>(
  (ref) => engineForThisPlatform(),
);

/// A video for the per-moment colour providers. Two keys are equal when
/// they read the same file, so saving an adjustment (which changes the item)
/// does not extract the frames again.
class VideoTrackKey extends Equatable {
  const VideoTrackKey(this.item);

  final MediaItem item;

  @override
  List<Object?> get props => [colorStatsKey(item)];
}

/// One extraction at a time across the app: each decodes a whole clip's
/// worth of seeks, and a grid of videos must not start them all at once.
Future<void> _gate = Future.value();

Future<T> _serially<T>(Future<T> Function() work) {
  final run = _gate.then((_) => work());
  _gate = run.then((_) {}, onError: (_) {});
  return run;
}

/// A video's automatic colour through the clip (issue #3520): seven frames
/// sampled across it, each corrected for the depth the dive profile gives
/// at that moment. Null when it cannot be worked out (no playable file, no
/// duration, no readable frame, no engine), in which case the video falls
/// back to its poster's colour, like a photo.
final videoColorTrackProvider =
    FutureProvider.family<VideoColorTrack?, VideoTrackKey>((ref, key) async {
      final item = key.item;
      final engine = ref.watch(transcodeEngineProvider);
      final seconds = item.durationSeconds;
      if (engine == null || seconds == null || seconds <= 0) return null;
      final path = await ref.watch(resolvedFilePathProvider(item).future);
      if (path == null) return null;

      final depthAt = await ref.watch(videoDepthAtProvider(key).future);
      final times = frameSampleTimes(Duration(seconds: seconds));
      final List<Uint8List?> frames;
      try {
        frames = await _serially(
          () => engine.extractFrames(
            source: File(path),
            times: [
              for (final t in times) Duration(milliseconds: (t * 1000).round()),
            ],
          ),
        );
      } catch (e, stackTrace) {
        _log.warning(
          'Frame extraction failed for media ${item.id}',
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }

      final keys = <VideoColorKey>[];
      for (var i = 0; i < times.length && i < frames.length; i++) {
        final stats = _statsOf(frames[i]);
        if (stats == null) continue;
        final depth = depthAt?.call(times[i]);
        final params = depth == null && !stats.looksUnderwater
            ? AutoCorrectionParams.none
            : computeAutoCorrection(stats, depthMeters: depth);
        keys.add(VideoColorKey(seconds: times[i], params: params));
      }
      return keys.isEmpty ? null : VideoColorTrack(keys);
    });

/// The depth at a moment of the clip, from the dive profile; null when the
/// dive has no profile or the clip has no place in it.
final videoDepthAtProvider =
    FutureProvider.family<double? Function(double seconds)?, VideoTrackKey>((
      ref,
      key,
    ) async {
      final diveId = key.item.diveId;
      final start = key.item.enrichment?.elapsedSeconds;
      if (diveId == null || start == null) return null;
      try {
        final profile = await ref.watch(diveProfileProvider(diveId).future);
        return profile.isEmpty ? null : videoDepthLookup(profile, start);
      } catch (_) {
        return null;
      }
    });

/// Depth [seconds] into a clip that starts [startElapsedSeconds] into the
/// dive, interpolated from [profile]. A moment before the first sample or
/// after the last is at the surface (0 m, so no correction); with no
/// profile or no start the depth is unknown (null, so no depth limit).
double? Function(double seconds) videoDepthLookup(
  List<DiveProfilePoint> profile,
  int? startElapsedSeconds,
) {
  if (startElapsedSeconds == null || profile.isEmpty) return (_) => null;
  final sorted = List.of(profile)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return (seconds) {
    final at = startElapsedSeconds + seconds;
    if (at < sorted.first.timestamp || at > sorted.last.timestamp) return 0;
    for (var i = 1; i < sorted.length; i++) {
      final hi = sorted[i];
      if (hi.timestamp < at) continue;
      final lo = sorted[i - 1];
      final span = hi.timestamp - lo.timestamp;
      if (span <= 0) return hi.depth;
      return lo.depth + (hi.depth - lo.depth) * (at - lo.timestamp) / span;
    }
    return sorted.last.depth;
  };
}

ChannelStats? _statsOf(Uint8List? jpeg) {
  if (jpeg == null) return null;
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) return null;
  return ChannelStats.fromRgba(
    decoded.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
  );
}
