import 'dart:async';
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
  final List<String> sources = [];
  bool throws = false;

  @override
  Future<List<Uint8List?>> extractFrames({
    required File source,
    required List<Duration> times,
    int maxDimension = 160,
    bool exact = false,
  }) async {
    requests.add(times);
    sources.add(source.path);
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
  var originalFetches = 0;

  ProviderContainer container(
    _FakeEngine engine, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final c = ProviderContainer(
      overrides: [
        transcodeEngineProvider.overrideWithValue(engine),
        // A grid must never fetch a whole original to colour a tile.
        resolvedFilePathProvider.overrideWith((ref, item) async {
          originalFetches++;
          return '/cache/original.mp4';
        }),
        diveProfileProvider.overrideWith((ref, id) async => profile),
        videoFrameTimeoutProvider.overrideWithValue(timeout),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Reads a clip's track while holding it, as a tile on screen does: the
  /// track and its frames auto-dispose with nobody listening.
  Future<VideoColorTrack?> readTrack(ProviderContainer c, VideoTrackKey k) {
    final sub = c.listen(videoColorTrackProvider(k), (_, _) {});
    addTearDown(sub.close);
    return c.read(videoColorTrackProvider(k).future);
  }

  setUp(() => originalFetches = 0);

  VideoTrackKey key(MediaItem item, {String? path = '/v/dive.mp4'}) =>
      VideoTrackKey(item, path: path);

  test('samples seven frames at the pinned times and warms each', () async {
    final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
    final track = await readTrack(container(engine), key(video()));

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
    final track = await readTrack(container(engine), key(video()));
    expect(track!.keys, hasLength(4));
  });

  test('no readable frame falls back to the poster (null track)', () async {
    final engine = _FakeEngine((t) => List.filled(t.length, null));
    expect(await readTrack(container(engine), key(video())), isNull);
  });

  test('an engine that throws falls back to the poster', () async {
    final engine = _FakeEngine((t) => [])..throws = true;
    expect(await readTrack(container(engine), key(video())), isNull);
  });

  test(
    'a video with no local file uses its poster and fetches nothing',
    () async {
      final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
      expect(
        await readTrack(container(engine), key(video(), path: null)),
        isNull,
      );
      expect(engine.requests, isEmpty);
      expect(originalFetches, 0);
    },
  );

  test('a stuck extraction times out and does not block the next', () async {
    var calls = 0;
    final engine = _StuckOnceEngine(() => calls++);
    final c = container(engine, timeout: const Duration(milliseconds: 50));
    expect(
      await readTrack(c, key(video())).timeout(const Duration(seconds: 2)),
      isNull,
    );
    final other = video().copyWith(localPath: '/v/other.mp4');
    expect(
      await readTrack(
        c,
        key(other, path: '/v/other.mp4'),
      ).timeout(const Duration(seconds: 2)),
      isNotNull,
    );
  });

  test('a dive profile refresh does not read the frames again', () async {
    // Every dive edit, anywhere, ticks the profile provider
    // (watchDiveDetailChanges); the frames depend only on the file.
    final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
    final c = container(engine);
    final k = key(video());
    final sub = c.listen(videoColorTrackProvider(k), (_, _) {});
    addTearDown(sub.close);
    final first = await readTrack(c, k);

    c.invalidate(diveProfileProvider('d1'));
    final second = await readTrack(c, k);

    expect(engine.requests, hasLength(1));
    expect(second, first);
  });

  test(
    'a new depth placement re-bounds the frames without reading them',
    () async {
      // A re-match moves the clip in the dive: the depth at each moment
      // changes, the pixels do not.
      final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
      final c = container(engine);
      final a = video();
      final moved = a.copyWith(
        enrichment: a.enrichment!.copyWith(elapsedSeconds: 1490),
      );
      final before = await readTrack(c, key(a));
      final after = await readTrack(c, key(moved));

      expect(engine.requests, hasLength(1));
      // 1490 s in, the clip runs past the profile's end: surface, no fix.
      expect(after!.keys.last.params, AutoCorrectionParams.none);
      expect(before!.keys.last.params, isNot(AutoCorrectionParams.none));
    },
  );

  group('a row linked through a bookmark', () {
    // The sandboxed macOS build can stat a linked file by its path after a
    // relaunch but not open it; an iOS row keeps no path at all.
    final opened = <String?>[];
    VideoFileAccess fakeAccess(String resolved) =>
        <T>({path, bookmarkRef, required read}) async {
          opened.add(bookmarkRef);
          return bookmarkRef == null
              ? path == null
                    ? null
                    : read(path)
              : read(resolved);
        };

    setUp(opened.clear);

    ProviderContainer withAccess(_FakeEngine engine) {
      final c = ProviderContainer(
        overrides: [
          transcodeEngineProvider.overrideWithValue(engine),
          diveProfileProvider.overrideWith((ref, id) async => profile),
          videoFileAccessProvider.overrideWithValue(
            fakeAccess('/scoped/dive.mp4'),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('is read through its bookmark, not the bare path', () async {
      final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
      final linked = video().copyWith(bookmarkRef: 'bm-1');
      final track = await readTrack(withAccess(engine), key(linked));
      expect(track, isNotNull);
      expect(opened, ['bm-1']);
      expect(engine.sources.single, '/scoped/dive.mp4');
    });

    test('with no path at all (iOS) still gets its track', () async {
      final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
      final linked = video().copyWith(localPath: null, bookmarkRef: 'bm-1');
      final track = await readTrack(
        withAccess(engine),
        key(linked, path: null),
      );
      expect(track, isNotNull);
      expect(engine.sources.single, '/scoped/dive.mp4');
    });
  });

  test('an unknown duration falls back to the poster', () async {
    final engine = _FakeEngine((t) => [for (final _ in t) blueJpeg()]);
    expect(
      await readTrack(container(engine), key(video(duration: null))),
      isNull,
    );
  });

  test('keys compare by file and placement, not by edits', () {
    final a = video();
    expect(key(a), key(a.copyWith(caption: 'edited')));
    expect(key(a), isNot(key(a, path: '/v/other.mp4')));
    expect(key(a), isNot(key(a.copyWith(diveId: 'd2'))));
    expect(key(a), isNot(key(a.copyWith(durationSeconds: 90))));
    expect(
      key(a),
      isNot(
        key(
          a.copyWith(enrichment: a.enrichment!.copyWith(elapsedSeconds: 900)),
        ),
      ),
    );
  });

  group('videoDepthLookup', () {
    test('interpolates from the clip start into the profile', () {
      final depthAt = videoDepthLookup(profile, 150);
      expect(depthAt(0), 10);
      expect(depthAt(150), 20);
    });

    test('lands on samples exactly, including the last and repeated ones', () {
      expect(videoDepthLookup(profile, 0)(300), 20);
      expect(videoDepthLookup(profile, 0)(1500), 0);
      expect(videoDepthLookup(profile, 0)(1350), closeTo(10, 1e-9));
      const repeated = [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 100, depth: 10),
        DiveProfilePoint(timestamp: 100, depth: 12),
        DiveProfilePoint(timestamp: 200, depth: 12),
      ];
      expect(videoDepthLookup(repeated, 0)(50), 5);
      expect(videoDepthLookup(repeated, 0)(150), 12);
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

/// Never answers its first extraction; answers the rest with blue frames.
class _StuckOnceEngine extends _FakeEngine {
  _StuckOnceEngine(this.onCall) : super((t) => [for (final _ in t) blueJpeg()]);

  final int Function() onCall;

  @override
  Future<List<Uint8List?>> extractFrames({
    required File source,
    required List<Duration> times,
    int maxDimension = 160,
    bool exact = false,
  }) {
    if (onCall() == 0) return Completer<List<Uint8List?>>().future;
    return super.extractFrames(source: source, times: times);
  }
}
