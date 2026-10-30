import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

final _log = LoggerService.forClass(VideoTrackKey);

/// The platform's video engine (frame extraction lives beside transcoding).
final transcodeEngineProvider = Provider<TranscodeEngine?>(
  (ref) => engineForThisPlatform(),
);

/// A video for the per-moment colour providers, and the local [path] to
/// read its frames from.
///
/// Grid tiles pass only a file already on this device ([MediaItem.localPath],
/// or the row's bookmark to it); the viewer passes the file it is playing. A
/// video with no local file (store-only, a photo-library export) is never
/// fetched to colour a tile: its tile uses the poster until it is played.
///
/// Two keys are equal when they read the same file at the same place in the
/// same dive, so saving an adjustment (which changes the item) does not
/// extract the frames again, but a re-match or a new time pin does.
class VideoTrackKey extends Equatable {
  const VideoTrackKey(this.item, {this.path});

  final MediaItem item;
  final String? path;

  @override
  List<Object?> get props => [
    colorStatsKey(item),
    item.diveId,
    item.enrichment?.elapsedSeconds,
    item.durationSeconds,
    item.bookmarkRef,
    path,
  ];
}

/// Reads a video with [read] (its frames, or a corrected copy of it),
/// given a path to open. A row linked through a security-scoped bookmark
/// (iOS and macOS) is opened through it, with access held only for the
/// read: the sandboxed macOS build may stat a linked file by its path after
/// a relaunch but not open it, and an iOS row keeps no path at all.
/// Otherwise [path] as it is. Null when the file cannot be opened.
typedef VideoFileAccess =
    Future<T?> Function<T>({
      String? path,
      String? bookmarkRef,
      required Future<T> Function(String path) read,
    });

/// Whether this platform links files through security-scoped bookmarks.
final videoBookmarksApplyProvider = Provider<bool>(
  (ref) => Platform.isIOS || Platform.isMacOS,
);

final videoFileAccessProvider = Provider<VideoFileAccess>((ref) {
  final storage = ref.watch(localBookmarkStorageProvider);
  final platform = ref.watch(localMediaPlatformProvider);
  final bookmarksApply = ref.watch(videoBookmarksApplyProvider);
  return <T>({path, bookmarkRef, required read}) async {
    if (bookmarksApply && bookmarkRef != null && bookmarkRef.isNotEmpty) {
      ResolvedBookmark? lease;
      try {
        final blob = await storage.read(bookmarkRef);
        if (blob != null) lease = await platform.resolveBookmark(blob);
      } on Object catch (e, stackTrace) {
        // An unreadable bookmark is not fatal: the plain path may still open.
        _log.warning(
          'Opening a video through its bookmark failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
      if (lease != null) {
        try {
          return await read(lease.filePath);
        } finally {
          await platform.releaseBookmark(lease.bookmarkRef);
        }
      }
    }
    return path == null ? null : read(path);
  };
});

/// How long one clip's frame extraction may take before it is given up.
final videoFrameTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

/// One extraction at a time across the app: each decodes a whole clip's
/// worth of seeks, and a grid of videos must not start them all at once.
Future<void> _gate = Future.value();

Future<T> _serially<T>(Future<T> Function() work) {
  final run = _gate.then((_) => work());
  _gate = run.then((_) {}, onError: (_) {});
  return run;
}

/// One frame extraction behind the app's one-at-a-time gate, given up
/// after [timeout] (a native call that never answers must not hold the
/// queue). Every caller goes through here: the clip tracks and the
/// white-point pick on a paused video. [stillWanted] is asked when the
/// call's turn comes; false skips it (all nulls), for a tile scrolled away.
///
/// The file is [path], or opened through [access] (a bookmark), once the
/// call's turn comes, so no access is held while it waits.
Future<List<Uint8List?>> extractFramesGated(
  TranscodeEngine engine, {
  required String? path,
  required List<Duration> times,
  required Duration timeout,
  String? bookmarkRef,
  VideoFileAccess? access,
  int maxDimension = 160,
  bool exact = false,
  bool Function()? stillWanted,
}) => _serially(() async {
  final none = List<Uint8List?>.filled(times.length, null);
  if (stillWanted != null && !stillWanted()) return none;
  Future<List<Uint8List?>> read(String file) => engine
      .extractFrames(
        source: File(file),
        times: times,
        maxDimension: maxDimension,
        exact: exact,
      )
      .timeout(timeout);
  if (access == null) return path == null ? none : read(path);
  return await access(path: path, bookmarkRef: bookmarkRef, read: read) ?? none;
});

/// The colour of one frame sampled [seconds] into a clip.
typedef VideoFrameStats = ({double seconds, ChannelStats stats});

/// The file [videoFrameStatsProvider] reads frames from: the pixels alone,
/// not the clip's place in the dive.
class VideoFramesKey extends Equatable {
  const VideoFramesKey({
    required this.statsKey,
    required this.path,
    required this.durationSeconds,
    this.bookmarkRef,
  });

  /// [colorStatsKey] of the item, so relinking or replacing its file reads
  /// the frames again.
  final String statsKey;

  /// The file to read, or null when [bookmarkRef] is the only way to it.
  final String? path;
  final String? bookmarkRef;
  final int durationSeconds;

  @override
  List<Object?> get props => [statsKey, path, bookmarkRef, durationSeconds];
}

/// The colour of seven frames sampled across a clip: the slow part (native
/// seeks and decodes), kept apart from the depth that bounds it. A profile
/// refresh (every dive or media write ticks it), a re-match or a time pin
/// re-bounds these without reading the file again. Null when the frames
/// cannot be read (no engine, an unreadable file, a timeout).
final videoFrameStatsProvider = FutureProvider.autoDispose
    .family<List<VideoFrameStats>?, VideoFramesKey>((ref, key) async {
      final engine = ref.watch(transcodeEngineProvider);
      if (engine == null) return null;
      final timeout = ref.watch(videoFrameTimeoutProvider);
      final times = frameSampleTimes(Duration(seconds: key.durationSeconds));
      final List<Uint8List?> frames;
      try {
        frames = await extractFramesGated(
          engine,
          path: key.path,
          bookmarkRef: key.bookmarkRef,
          access: ref.watch(videoFileAccessProvider),
          times: [
            for (final t in times) Duration(milliseconds: (t * 1000).round()),
          ],
          timeout: timeout,
          // A tile scrolled away before its turn is not read: nobody would
          // see it, and every later clip waits behind it.
          stillWanted: () => ref.mounted,
        );
      } catch (e, stackTrace) {
        _log.warning(
          'Frame extraction failed for ${key.path}',
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
      if (!ref.mounted) return null;
      // Read once per file for the session: scrolling back to a clip must
      // not seek through it again.
      ref.keepAlive();
      // Seven software JPEG decodes: off the UI isolate.
      final stats = await compute(_statsOfAll, frames);
      return [
        for (var i = 0; i < times.length && i < stats.length; i++)
          if (stats[i] case final s?) (seconds: times[i], stats: s),
      ];
    });

/// A video's automatic colour through the clip (issue #3520): its sampled
/// frames, each corrected for the depth the dive profile gives at that
/// moment. Null when it cannot be worked out (no playable file, no
/// duration, no readable frame, no engine), in which case the video falls
/// back to its poster's colour, like a photo.
final videoColorTrackProvider = FutureProvider.autoDispose
    .family<VideoColorTrack?, VideoTrackKey>((ref, key) async {
      final item = key.item;
      final seconds = item.durationSeconds;
      final path = key.path;
      final bookmarkRef = item.bookmarkRef;
      final reachable = path != null || (bookmarkRef?.isNotEmpty ?? false);
      if (!reachable || seconds == null || seconds <= 0) return null;
      // Both watched before the first await: a ref is not to be used after
      // an async gap, by which time this provider may have been disposed.
      final framesFuture = ref.watch(
        videoFrameStatsProvider(
          VideoFramesKey(
            statsKey: colorStatsKey(item),
            path: path,
            bookmarkRef: bookmarkRef,
            durationSeconds: seconds,
          ),
        ).future,
      );
      final depthFuture = ref.watch(videoDepthAtProvider(key).future);
      final frames = await framesFuture;
      if (frames == null || frames.isEmpty) return null;
      final depthAt = await depthFuture;
      return VideoColorTrack([
        for (final (:seconds, :stats) in frames)
          VideoColorKey(
            seconds: seconds,
            params:
                autoParamsFor(stats, depthMeters: depthAt?.call(seconds)) ??
                AutoCorrectionParams.none,
          ),
      ]);
    });

/// The depth at a moment of the clip, from the dive profile; null when the
/// dive has no profile or the clip has no place in it.
final videoDepthAtProvider = FutureProvider.autoDispose
    .family<double? Function(double seconds)?, VideoTrackKey>((ref, key) async {
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
  // Asked on every playback position update: a binary search (the
  // profile's own), not a walk from the first sample.
  return (seconds) {
    final at = startElapsedSeconds + seconds;
    if (at < sorted.first.timestamp || at > sorted.last.timestamp) return 0;
    final i = indexForTimestamp(sorted, at.floor())!;
    final lo = sorted[i];
    if (i == sorted.length - 1) return lo.depth;
    final hi = sorted[i + 1];
    final span = hi.timestamp - lo.timestamp;
    if (span <= 0) return hi.depth;
    return lo.depth + (hi.depth - lo.depth) * (at - lo.timestamp) / span;
  };
}

List<ChannelStats?> _statsOfAll(List<Uint8List?> jpegs) => [
  for (final jpeg in jpegs) _statsOf(jpeg),
];

ChannelStats? _statsOf(Uint8List? jpeg) {
  if (jpeg == null) return null;
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) return null;
  return ChannelStats.fromRgba(
    decoded.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
  );
}
