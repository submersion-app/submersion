import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';

Uint8List solidRgba(int r, int g, int b, {int n = 16}) => Uint8List.fromList([
  for (var i = 0; i < n; i++) ...[r, g, b, 255],
]);

Uint8List bluePng() {
  final im = img.Image(width: 8, height: 8);
  img.fill(im, color: img.ColorRgb8(20, 100, 160));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = MemoryImage(Uint8List(0));

  test('decodes a real image into stats', () async {
    final service = ColorAnalysisService();
    final stats = await service.statsFor('k', MemoryImage(bluePng()));
    expect(stats, isNotNull);
    expect(stats!.meanR, closeTo(20 / 255, 0.01));
    expect(stats.meanB, closeTo(160 / 255, 0.01));
  });

  test('a source that is already a ResizeImage still decodes', () async {
    // Tiles draw ResizeImage.resizeIfNeeded(...); wrapping another
    // ResizeImage around it trips an assert in debug builds.
    final service = ColorAnalysisService();
    final stats = await service.statsFor(
      'k',
      ResizeImage(MemoryImage(bluePng()), width: 6),
    );
    expect(stats, isNotNull);
  });

  test('the small analysis decode does not stay in the image cache', () async {
    final source = MemoryImage(bluePng());
    await ColorAnalysisService().statsFor('k', source);
    final key = await ResizeImage(
      source,
      width: 64,
      height: 64,
      policy: ResizeImagePolicy.fit,
    ).obtainKey(ImageConfiguration.empty);
    expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
  });

  test('a decode that never answers times out and frees its slot', () async {
    var calls = 0;
    final service = ColorAnalysisService(
      decodeTimeout: const Duration(milliseconds: 50),
      decodeRgba: (_) {
        calls++;
        return calls <= 2
            ? Completer<Uint8List?>().future
            : Future.value(solidRgba(20, 100, 160));
      },
    );
    final stuck = [
      service.statsFor('a', source),
      service.statsFor('b', source),
    ];
    final later = service.statsFor('c', source);
    expect(await Future.wait(stuck).timeout(const Duration(seconds: 2)), [
      null,
      null,
    ]);
    expect(await later.timeout(const Duration(seconds: 2)), isNotNull);
  });

  test('a second request for the same key does not decode again', () async {
    var decodes = 0;
    final service = ColorAnalysisService(
      decodeRgba: (_) async {
        decodes++;
        return solidRgba(20, 100, 160);
      },
    );
    final a = await service.statsFor('k', source);
    final b = await service.statsFor('k', source);
    expect(a, b);
    expect(decodes, 1);
    expect(service.peek('k'), a);
  });

  test('concurrent requests for one key share a decode', () async {
    var decodes = 0;
    final gate = Completer<Uint8List?>();
    final service = ColorAnalysisService(
      decodeRgba: (_) {
        decodes++;
        return gate.future;
      },
    );
    final a = service.statsFor('k', source);
    final b = service.statsFor('k', source);
    gate.complete(solidRgba(20, 100, 160));
    expect(await a, await b);
    expect(decodes, 1);
  });

  test('a failed decode is null, never throws, and is tried again', () async {
    // A failure may be passing (a slow mount, the app backgrounded
    // mid-decode); remembering it would leave the photo uncorrected.
    var decodes = 0;
    final service = ColorAnalysisService(
      decodeRgba: (_) async {
        decodes++;
        if (decodes == 1) throw StateError('codec');
        return solidRgba(20, 100, 160);
      },
    );
    expect(await service.statsFor('k', source), isNull);
    expect(service.isKnown('k'), isFalse);
    expect(await service.statsFor('k', source), isNotNull);
    expect(decodes, 2);
  });

  test('a black frame is null stats, remembered', () async {
    var decodes = 0;
    final service = ColorAnalysisService(
      decodeRgba: (_) async {
        decodes++;
        return solidRgba(0, 0, 0);
      },
    );
    expect(await service.statsFor('k', source), isNull);
    expect(await service.statsFor('k', source), isNull);
    expect(service.isKnown('k'), isTrue);
    expect(decodes, 1);
  });

  test('a peek counts as a use, so drawn tiles outlive the rest', () async {
    final service = ColorAnalysisService(
      capacity: 2,
      decodeRgba: (_) async => solidRgba(20, 100, 160),
    );
    await service.statsFor('a', source);
    await service.statsFor('b', source);
    expect(service.peek('a'), isNotNull);
    await service.statsFor('c', source);
    expect(service.peek('a'), isNotNull);
    expect(service.peek('b'), isNull);
  });

  test('at most two decodes run at once', () async {
    final gates = <Completer<Uint8List?>>[];
    final service = ColorAnalysisService(
      decodeRgba: (_) {
        final c = Completer<Uint8List?>();
        gates.add(c);
        return c.future;
      },
    );
    final results = [
      for (final k in ['a', 'b', 'c']) service.statsFor(k, source),
    ];
    await pumpEventQueue();
    expect(gates, hasLength(2));
    gates[0].complete(solidRgba(20, 100, 160));
    await pumpEventQueue();
    expect(gates, hasLength(3));
    gates[1].complete(solidRgba(20, 100, 160));
    gates[2].complete(solidRgba(20, 100, 160));
    expect(await Future.wait(results), everyElement(isA<ChannelStats>()));
  });

  test('the cache keeps at most its capacity, oldest out first', () async {
    var decodes = 0;
    final service = ColorAnalysisService(
      capacity: 2,
      decodeRgba: (_) async {
        decodes++;
        return solidRgba(20, 100, 160);
      },
    );
    await service.statsFor('a', source);
    await service.statsFor('b', source);
    await service.statsFor('c', source);
    expect(service.peek('a'), isNull);
    expect(service.peek('c'), isNotNull);
    await service.statsFor('a', source);
    expect(decodes, 4);
  });

  group('the queue after a fling (issue #3868)', () {
    late List<String> started;
    late List<Completer<Uint8List?>> gates;
    late ColorAnalysisService service;

    /// A source that names its key, so the decoder can record the order.
    ImageProvider sourceOf(String key) =>
        MemoryImage(Uint8List.fromList(key.codeUnits));

    /// Answers the [index]th started decode, then lets the queue move on.
    Future<void> finish(int index) async {
      gates[index].complete(solidRgba(20, 100, 160));
      await pumpEventQueue();
    }

    setUp(() {
      started = [];
      gates = [];
      service = ColorAnalysisService(
        decodeRgba: (provider) {
          started.add(String.fromCharCodes((provider as MemoryImage).bytes));
          final gate = Completer<Uint8List?>();
          gates.add(gate);
          return gate.future;
        },
      );
    });

    // Finishes every decode, including those the queue starts on the way: a
    // timeout left running would fire in another file of CI's shared isolate.
    tearDown(() async {
      for (var i = 0; i < gates.length; i++) {
        if (!gates[i].isCompleted) gates[i].complete(null);
        await pumpEventQueue();
      }
    });

    test('the newest request starts ahead of an older backlog', () async {
      for (var i = 0; i < 32; i++) {
        unawaited(service.statsFor('old-$i', sourceOf('old-$i')));
      }
      final visible = service.statsFor('visible', sourceOf('visible'));
      await pumpEventQueue();
      expect(started, ['old-0', 'old-1']);

      await finish(0);
      expect(started, ['old-0', 'old-1', 'visible']);

      await finish(2);
      expect(await visible, isNotNull);
    });

    test('asking again moves a queued key to the front', () async {
      for (final key in ['a', 'b', 'c', 'd']) {
        unawaited(service.statsFor(key, sourceOf(key)));
      }
      await pumpEventQueue();
      unawaited(service.statsFor('c', sourceOf('c')));

      await finish(0);
      expect(started, ['a', 'b', 'c']);
    });

    test('asking again for a running key does not start it twice', () async {
      final first = service.statsFor('a', sourceOf('a'));
      final second = service.statsFor('a', sourceOf('a'));
      unawaited(service.statsFor('b', sourceOf('b')));
      unawaited(service.statsFor('c', sourceOf('c')));
      await pumpEventQueue();

      await finish(0);
      expect(started, ['a', 'b', 'c']);
      expect(await first, await second);
    });

    test('a queued key with no consumers left never decodes', () async {
      unawaited(service.statsFor('a', sourceOf('a')));
      unawaited(service.statsFor('b', sourceOf('b')));
      service.request('kept', sourceOf('kept'));
      final obsolete = service.request('obsolete', sourceOf('obsolete'));

      obsolete.cancel();
      expect(service.isPending('obsolete'), isFalse);
      expect(await obsolete.stats, isNull);

      await finish(0);
      await finish(1);
      expect(started, ['a', 'b', 'kept']);
      expect(service.hasAnswer('obsolete'), isFalse);
    });

    test('a key dropped from the queue can be asked for again', () async {
      unawaited(service.statsFor('a', sourceOf('a')));
      unawaited(service.statsFor('b', sourceOf('b')));
      service.request('k', sourceOf('k')).cancel();

      final again = service.request('k', sourceOf('k'));
      await finish(0);
      expect(started, ['a', 'b', 'k']);
      await finish(2);
      expect(await again.stats, isNotNull);
    });

    test('a key stays queued until its last consumer cancels', () async {
      unawaited(service.statsFor('a', sourceOf('a')));
      unawaited(service.statsFor('b', sourceOf('b')));
      final first = service.request('shared', sourceOf('shared'));
      final second = service.request('shared', sourceOf('shared'));

      first.cancel();
      expect(service.isPending('shared'), isTrue);

      await finish(0);
      expect(started, ['a', 'b', 'shared']);
      await finish(2);
      expect(await second.stats, isNotNull);
      expect(await first.stats, isNotNull);
    });

    test('cancelling twice counts once', () async {
      unawaited(service.statsFor('a', sourceOf('a')));
      unawaited(service.statsFor('b', sourceOf('b')));
      final first = service.request('shared', sourceOf('shared'));
      service.request('shared', sourceOf('shared'));

      first
        ..cancel()
        ..cancel();
      expect(service.isPending('shared'), isTrue);
    });

    test('a caller that cannot cancel keeps a shared key alive', () async {
      // A share awaits its stats with no widget to go away, so a tile
      // leaving the same key behind must not take the share's answer.
      unawaited(service.statsFor('a', sourceOf('a')));
      unawaited(service.statsFor('b', sourceOf('b')));
      final tile = service.request('shared', sourceOf('shared'));
      final share = service.statsFor('shared', sourceOf('shared'));

      tile.cancel();
      await finish(0);
      await finish(2);
      expect(await share, isNotNull);
    });

    test('cancelling a running key still caches its answer', () async {
      final running = service.request('k', sourceOf('k'));
      await pumpEventQueue();

      running.cancel();
      expect(service.isPending('k'), isTrue);

      await finish(0);
      expect(service.peek('k'), isNotNull);
    });

    test('a spent request cannot cancel a later one for its key', () async {
      // Failed, so not remembered: the next ask queues the key afresh.
      final spent = service.request('k', sourceOf('k'));
      gates.single.complete(null);
      await pumpEventQueue();
      unawaited(service.statsFor('a', sourceOf('a')));
      unawaited(service.statsFor('b', sourceOf('b')));
      service.request('k', sourceOf('k'));

      spent.cancel();
      expect(service.isPending('k'), isTrue);
    });

    test('a cache hit answers at once and has nothing to cancel', () async {
      final miss = service.request('k', sourceOf('k'));
      await finish(0);
      final stats = await miss.stats;

      final hit = service.request('k', sourceOf('k'));
      hit.cancel();
      expect(await hit.stats, stats);
      expect(service.peek('k'), stats);
      expect(started, ['k']);
    });

    test('decodes never exceed two once the queue has moved', () async {
      for (final key in ['a', 'b', 'c', 'd', 'e']) {
        unawaited(service.statsFor(key, sourceOf(key)));
      }
      await pumpEventQueue();
      expect(started, hasLength(2));
      await finish(0);
      expect(started, hasLength(3));
      await finish(1);
      expect(started, hasLength(4));
    });
  });
}
