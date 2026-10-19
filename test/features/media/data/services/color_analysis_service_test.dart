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
}
