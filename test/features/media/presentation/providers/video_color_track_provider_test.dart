import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

Uint8List blueJpeg() => Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 32, height: 32)..clear(img.ColorRgb8(20, 100, 160)),
  ),
);

class _FakeEngine implements TranscodeEngine {
  _FakeEngine(this.frames);

  final List<Uint8List?> Function(List<Duration> times) frames;
  final List<List<Duration>> requests = [];
  bool throws = false;

  @override
  Future<List<Uint8List?>> extractFrames({
    required File source,
    required List<Duration> times,
    int maxDimension = 160,
  }) async {
    requests.add(times);
    if (throws) throw StateError('codec');
    return frames(times);
  }

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<VideoProbe?> probe(File source) async => null;
  @override
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  }) async {}
}

MediaItem video({int? duration = 70}) => MediaItem(
  id: 'v1',
  diveId: 'd1',
  mediaType: MediaType.video,
  sourceType: MediaSourceType.localFile,
  localPath: '/v/dive.mp4',
  durationSeconds: duration,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  enrichment: MediaEnrichment(
    id: 'e',
    mediaId: 'v1',
    diveId: 'd1',
    depthMeters: 20,
    elapsedSeconds: 600,
    matchConfidence: MatchConfidence.interpolated,
    createdAt: DateTime.utc(2026),
  ),
);

const profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 300, depth: 20),
  DiveProfilePoint(timestamp: 1200, depth: 20),
  DiveProfilePoint(timestamp: 1500, depth: 0),
];

void main() {
  ProviderContainer container(
    _FakeEngine engine, {
    String? path = '/v/dive.mp4',
  }) {
    final c = ProviderContainer(
      overrides: [
        transcodeEngineProvider.overrideWithValue(engine),
        resolvedFilePathProvider.overrideWith((ref, item) async => path),
        diveProfileProvider.overrideWith((ref, id) async => profile),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('samples seven frames at the pinned times and warms each', () async {
    final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
    final track = await container(
      engine,
    ).read(videoColorTrackProvider(VideoTrackKey(video())).future);

    expect(engine.requests.single, [
      for (final s in [5, 15, 25, 35, 45, 55, 65]) Duration(seconds: s),
    ]);
    expect(track!.keys, hasLength(7));
    final stats = ChannelStats.fromRgba(
      img.decodeJpg(blueJpeg())!.getBytes(order: img.ChannelOrder.rgba),
    )!;
    expect(
      track.keys.first.params,
      computeAutoCorrection(stats, depthMeters: 20),
    );
    expect(track.keys.first.seconds, 5);
  });

  test('frames that cannot be read are dropped', () async {
    final engine = _FakeEngine(
      (t) => [for (var i = 0; i < t.length; i++) i.isEven ? blueJpeg() : null],
    );
    final track = await container(
      engine,
    ).read(videoColorTrackProvider(VideoTrackKey(video())).future);
    expect(track!.keys, hasLength(4));
  });

  test('no readable frame falls back to the poster (null track)', () async {
    final engine = _FakeEngine((t) => List.filled(t.length, null));
    expect(
      await container(
        engine,
      ).read(videoColorTrackProvider(VideoTrackKey(video())).future),
      isNull,
    );
  });

  test('an engine that throws falls back to the poster', () async {
    final engine = _FakeEngine((t) => [])..throws = true;
    expect(
      await container(
        engine,
      ).read(videoColorTrackProvider(VideoTrackKey(video())).future),
      isNull,
    );
  });

  test('no playable file never asks the engine', () async {
    final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
    expect(
      await container(
        engine,
        path: null,
      ).read(videoColorTrackProvider(VideoTrackKey(video())).future),
      isNull,
    );
    expect(engine.requests, isEmpty);
  });

  test('an unknown duration falls back to the poster', () async {
    final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
    expect(
      await container(engine).read(
        videoColorTrackProvider(VideoTrackKey(video(duration: null))).future,
      ),
      isNull,
    );
  });

  test('keys compare by file, not by edits', () {
    final a = video();
    expect(VideoTrackKey(a), VideoTrackKey(a.copyWith(caption: 'edited')));
    expect(
      VideoTrackKey(a),
      isNot(VideoTrackKey(a.copyWith(localPath: '/v/other.mp4'))),
    );
  });

  group('videoDepthLookup', () {
    test('interpolates from the clip start into the profile', () {
      final depthAt = videoDepthLookup(profile, 150);
      expect(depthAt(0), 10);
      expect(depthAt(150), 20);
    });

    test('is surface (0 m) outside the recorded profile', () {
      // 1490 + 60 s is past the last sample: the diver has surfaced.
      expect(videoDepthLookup(profile, 1490)(60), 0);
      expect(videoDepthLookup(profile, -30)(0), 0);
    });

    test('is unknown (null) without a profile or a start', () {
      expect(videoDepthLookup(profile, null)(10), isNull);
      expect(videoDepthLookup(const [], 10)(10), isNull);
    });
  });

  test('a moment outside the profile gets no correction', () {
    final params = computeAutoCorrection(
      const ChannelStats(meanR: 0.08, meanG: 0.4, meanB: 0.55),
      depthMeters: 20,
    );
    final track = VideoColorTrack([VideoColorKey(seconds: 0, params: params)]);
    expect(
      track.paramsAt(60, depthAt: videoDepthLookup(profile, 1490)),
      AutoCorrectionParams.none,
    );
    expect(track.paramsAt(60, depthAt: videoDepthLookup(profile, 600)), params);
  });
}
