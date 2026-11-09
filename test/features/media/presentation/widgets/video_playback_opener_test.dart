import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/widgets/video_playback_opener.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A player per created controller. A source whose URI is in [failing]
/// fails to initialise; every other one initialises at once.
class _FakePlatform extends VideoPlayerPlatform {
  final Set<String> failing = {};

  /// Sources whose seek the platform refuses.
  final Set<String> failingSeeks = {};
  final Map<int, StreamController<VideoEvent>> _events = {};
  final Map<int, String> sources = {};
  final Map<int, Duration> seeks = {};
  final Set<int> playing = {};
  final Set<int> disposed = {};
  int _next = 0;

  /// When set, every player waits for it before it is created.
  Completer<void>? createGate;

  Future<int?> _create(DataSource source) async {
    final gate = createGate;
    if (gate != null) await gate.future;
    final id = ++_next;
    final uri = source.uri ?? '';
    sources[id] = uri;
    // Announced once the controller listens: a broadcast stream drops
    // whatever is added before that.
    late final StreamController<VideoEvent> events;
    events = _events[id] = StreamController<VideoEvent>.broadcast(
      onListen: () => scheduleMicrotask(() {
        if (failing.contains(uri)) {
          events.addError(
            PlatformException(code: 'VideoError', message: 'cannot decode'),
          );
        } else {
          events.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: const Duration(seconds: 60),
              size: const Size(640, 360),
              rotationCorrection: 0,
            ),
          );
        }
      }),
    );
    return id;
  }

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) => _create(dataSource);
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      _create(options.dataSource);
  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async => playing.add(playerId);
  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    if (failingSeeks.contains(sources[playerId])) {
      throw PlatformException(code: 'SeekError', message: 'refused');
    }
    seeks[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      seeks[playerId] ?? Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  int idOf(VideoPlayerController controller) =>
      sources.entries.lastWhere((e) => e.value == controller.dataSource).key;

  /// Fails a player that already started, as an expired link does.
  void failAfterStart(VideoPlayerController controller) =>
      _events[idOf(controller)]!.addError(
        PlatformException(code: 'VideoError', message: 'link expired'),
      );
}

/// A candidate whose every open gives a new numbered URL under [name].
class _Candidate {
  _Candidate(this.name, this.tier);

  final String name;
  final ServedTier tier;
  final List<Uri> opened = [];
  final List<Uri> closed = [];

  StreamCandidate get candidate => StreamCandidate(
    tier: tier,
    open: () async {
      final url = Uri.parse('https://store.test/$name/${opened.length + 1}');
      opened.add(url);
      return url;
    },
    close: closed.add,
  );
}

void main() {
  late _FakePlatform platform;
  late List<Future<void>> releasing;
  late List<VideoPlayerController> created;

  setUp(() {
    final original = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    platform = _FakePlatform();
    VideoPlayerPlatform.instance = platform;
    // Runs before the restore above: a release still running after it
    // would reach the real platform.
    releasing = [];
    created = [];
    // Every player made here, disposed before the restore: a playing one
    // polls its position on a timer that would otherwise reach the real
    // platform after the test (CI runs many files in one isolate).
    addTearDown(() async {
      await Future.wait(releasing);
      await Future.wait(created.map((c) => c.dispose()));
    });
  });

  VideoPlayerController network(Uri url) {
    final controller = VideoPlayerController.networkUrl(url);
    created.add(controller);
    return controller;
  }

  VideoPlayerController file(String path) {
    final controller = VideoPlayerController.file(File(path));
    created.add(controller);
    return controller;
  }

  void release(VideoPlayerController controller) =>
      releasing.add(controller.dispose());

  VideoPlaybackOpener openerFor(List<_Candidate> candidates) =>
      VideoPlaybackOpener(
        StreamPlayback([for (final c in candidates) c.candidate]),
        release: release,
        network: network,
      );

  test(
    'falls back to the rendition when the original fails to initialise',
    () async {
      final original = _Candidate('original', ServedTier.original);
      final rendition = _Candidate('rendition', ServedTier.rendition);
      platform.failing.add('https://store.test/original/1');
      final opener = openerFor([original, rendition]);
      final controller = await opener.open();
      expect(controller.dataSource, 'https://store.test/rendition/1');
      expect(controller.value.isInitialized, isTrue);
      expect(original.closed, original.opened);
      expect(platform.disposed, contains(1));
    },
  );

  test('throws when every candidate fails', () async {
    final original = _Candidate('original', ServedTier.original);
    platform.failing.add('https://store.test/original/1');
    final opener = openerFor([original]);
    await expectLater(opener.open(), throwsA(isA<PlatformException>()));
    expect(original.closed, original.opened);
  });

  test(
    'reopens once after an error at the same position and play state',
    () async {
      final original = _Candidate('original', ServedTier.original);
      final opener = openerFor([original]);
      final first = await opener.open();
      await first.seekTo(const Duration(seconds: 12));
      await first.play();
      final next = await opener.reopenAfterError(first);
      expect(next, isNotNull);
      expect(next!.dataSource, 'https://store.test/original/2');
      final id = platform.idOf(next);
      expect(platform.seeks[id], const Duration(seconds: 12));
      expect(platform.playing, contains(id));
      expect(original.closed, [Uri.parse('https://store.test/original/1')]);
    },
  );

  group('watch', () {
    test(
      'a player that fails is reopened where it was and as it was',
      () async {
        // An error resets a controller's value to position zero, paused:
        // the resume point has to come from before the error.
        final original = _Candidate('original', ServedTier.original);
        final opener = openerFor([original]);
        final first = await opener.open();
        final replaced = Completer<VideoPlayerController?>();
        opener.watch(first, onReplaced: replaced.complete);
        await first.seekTo(const Duration(seconds: 12));
        await first.play();
        platform.failAfterStart(first);
        final next = await replaced.future;
        expect(next!.dataSource, 'https://store.test/original/2');
        final id = platform.idOf(next);
        expect(platform.seeks[id], const Duration(seconds: 12));
        expect(platform.playing, contains(id));
        await Future.wait(releasing);
        expect(platform.disposed, contains(platform.idOf(first)));
        expect(original.closed, [Uri.parse('https://store.test/original/1')]);
      },
    );

    test('a player that failed before it was watched is reopened', () async {
      final original = _Candidate('original', ServedTier.original);
      final opener = openerFor([original]);
      final first = await opener.open();
      platform.failAfterStart(first);
      await pumpEventQueue();
      expect(first.value.hasError, isTrue);
      final replaced = Completer<VideoPlayerController?>();
      opener.watch(first, onReplaced: replaced.complete);
      final next = await replaced.future;
      expect(next!.dataSource, 'https://store.test/original/2');
    });

    test('the reopened player is watched in turn', () async {
      final original = _Candidate('original', ServedTier.original);
      final rendition = _Candidate('rendition', ServedTier.rendition);
      final opener = openerFor([original, rendition]);
      final first = await opener.open();
      // Broadcast, so each step listens only for its own replacement.
      final replacements = StreamController<VideoPlayerController?>.broadcast();
      addTearDown(replacements.close);
      opener.watch(first, onReplaced: replacements.add);
      await first.seekTo(const Duration(seconds: 12));
      platform.failAfterStart(first);
      final again = (await replacements.stream.first)!;
      // Fails again where it resumed: it will not decode, so the rendition.
      platform.failAfterStart(again);
      final last = (await replacements.stream.first)!;
      expect(last.dataSource, 'https://store.test/rendition/1');
      expect(platform.seeks[platform.idOf(last)], const Duration(seconds: 12));
    });

    test('with nothing left to try the caller is told null', () async {
      final original = _Candidate('original', ServedTier.original);
      final opener = openerFor([original]);
      final first = await opener.open();
      platform.failing.add('https://store.test/original/2');
      final replaced = Completer<VideoPlayerController?>();
      opener.watch(first, onReplaced: replaced.complete);
      platform.failAfterStart(first);
      expect(await replaced.future, isNull);
      await Future.wait(releasing);
      expect(platform.disposed, contains(platform.idOf(first)));
    });

    test('dispose during a reopen releases the late player', () async {
      final original = _Candidate('original', ServedTier.original);
      final opener = openerFor([original]);
      final first = await opener.open();
      var told = false;
      opener.watch(first, onReplaced: (_) => told = true);
      // The reopened player is still being created when the caller leaves.
      final gate = Completer<void>();
      platform.createGate = gate;
      platform.failAfterStart(first);
      await pumpEventQueue();
      opener.dispose();
      gate.complete();
      await pumpEventQueue();
      expect(told, isFalse);
      await Future.wait(releasing);
      expect(platform.disposed, contains(2));
      // The caller still holds the failed one and releases it itself.
      expect(platform.disposed, isNot(contains(1)));
    });
  });

  test('a reopen whose seek fails releases the player it opened', () async {
    final original = _Candidate('original', ServedTier.original);
    final opener = openerFor([original]);
    final first = await opener.open();
    await first.seekTo(const Duration(seconds: 12));
    platform.failingSeeks.add('https://store.test/original/2');
    await expectLater(
      opener.reopenAfterError(first),
      throwsA(isA<PlatformException>()),
    );
    await Future.wait(releasing);
    expect(platform.disposed, contains(2));
    expect(original.closed, original.opened);
  });

  test('a second error in a row returns null', () async {
    final original = _Candidate('original', ServedTier.original);
    final opener = openerFor([original]);
    final first = await opener.open();
    await first.seekTo(const Duration(seconds: 12));
    final next = await opener.reopenAfterError(first);
    // Fails again before playing on from where it resumed.
    expect(await opener.reopenAfterError(next!), isNull);
  });

  test('an error after playback moved on reopens again', () async {
    final original = _Candidate('original', ServedTier.original);
    final opener = openerFor([original]);
    final first = await opener.open();
    await first.seekTo(const Duration(seconds: 12));
    final next = await opener.reopenAfterError(first);
    await next!.seekTo(const Duration(seconds: 20));
    expect(await opener.reopenAfterError(next), isNotNull);
  });

  test('dispose closes relay URLs', () async {
    final original = _Candidate('original', ServedTier.original);
    final opener = openerFor([original]);
    final first = await opener.open();
    await opener.reopenAfterError(first);
    opener.dispose();
    expect(original.closed, original.opened);
  });

  test('a file plays from its path and is not reopened', () async {
    final opener = VideoPlaybackOpener(
      const FilePlayback('/videos/clip.mp4'),
      release: release,
      network: network,
      file: file,
    );
    final controller = await opener.open();
    expect(controller.dataSource, endsWith('/videos/clip.mp4'));
    expect(await opener.reopenAfterError(controller), isNull);
  });

  test('a second error in a row moves on to the rendition', () async {
    // The original's metadata parses but it will not decode: reopening it
    // fails again where it was, so the rendition plays from there.
    final original = _Candidate('original', ServedTier.original);
    final rendition = _Candidate('rendition', ServedTier.rendition);
    final opener = openerFor([original, rendition]);
    final first = await opener.open();
    await first.seekTo(const Duration(seconds: 12));
    final again = await opener.reopenAfterError(first);
    final next = await opener.reopenAfterError(again!);
    expect(next, isNotNull);
    expect(next!.dataSource, 'https://store.test/rendition/1');
    expect(platform.seeks[platform.idOf(next)], const Duration(seconds: 12));
    expect(original.closed, original.opened);
  });

  test('an address opened after dispose is released at once', () async {
    final gate = Completer<void>();
    final closed = <Uri>[];
    final opener = VideoPlaybackOpener(
      StreamPlayback([
        StreamCandidate(
          tier: ServedTier.original,
          open: () async {
            await gate.future;
            return Uri.parse('https://store.test/late');
          },
          close: closed.add,
        ),
      ]),
      release: release,
      network: network,
      file: file,
    );
    final opening = opener.open();
    opener.dispose();
    gate.complete();
    await expectLater(opening, throwsA(isA<StateError>()));
    expect(closed, [Uri.parse('https://store.test/late')]);
  });
}
