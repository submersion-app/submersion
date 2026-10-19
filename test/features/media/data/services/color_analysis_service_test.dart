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

  test('a failed decode is null, memoized, and never throws', () async {
    var decodes = 0;
    final service = ColorAnalysisService(
      decodeRgba: (_) async {
        decodes++;
        throw StateError('codec');
      },
    );
    expect(await service.statsFor('k', source), isNull);
    expect(await service.statsFor('k', source), isNull);
    expect(decodes, 1);
  });

  test('a black frame is null stats', () async {
    final service = ColorAnalysisService(
      decodeRgba: (_) async => solidRgba(0, 0, 0),
    );
    expect(await service.statsFor('k', source), isNull);
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
