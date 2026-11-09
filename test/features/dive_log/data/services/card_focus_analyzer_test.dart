import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/services/card_focus_analyzer.dart';
import 'package:submersion/features/media/data/services/small_image_decoder.dart';

final _source = MemoryImage(Uint8List(0));

/// A 4x4 image, bright enough to be analysed.
SmallImage _small() =>
    (rgba: Uint8List.fromList(List.filled(64, 180)), width: 4, height: 4);

void main() {
  group('CardFocusAnalyzer', () {
    test('returns one score per decoded row', () async {
      final analyzer = CardFocusAnalyzer(decode: (_) async => _small());
      final rows = await analyzer.rowScoresFor('m1', _source);
      expect(rows, hasLength(4));
    });

    test('decodes a key once and serves the cache after', () async {
      var decodes = 0;
      final analyzer = CardFocusAnalyzer(
        decode: (_) async {
          decodes++;
          return _small();
        },
      );
      await analyzer.rowScoresFor('m1', _source);
      await analyzer.rowScoresFor('m1', _source);
      expect(decodes, 1);
      expect(analyzer.hasAnswer('m1'), isTrue);
      expect(analyzer.peek('m1'), hasLength(4));
    });

    test('shares one decode between callers waiting at once', () async {
      var decodes = 0;
      final gate = Completer<SmallImage?>();
      final analyzer = CardFocusAnalyzer(
        decode: (_) {
          decodes++;
          return gate.future;
        },
      );
      final a = analyzer.rowScoresFor('m1', _source);
      final b = analyzer.rowScoresFor('m1', _source);
      gate.complete(_small());
      expect(await a, await b);
      expect(decodes, 1);
    });

    test('answers null when the decode fails, and tries again later', () async {
      var decodes = 0;
      final analyzer = CardFocusAnalyzer(
        decode: (_) async {
          decodes++;
          throw StateError('no bytes');
        },
      );
      expect(await analyzer.rowScoresFor('m1', _source), isNull);
      expect(analyzer.hasAnswer('m1'), isFalse);
      await analyzer.rowScoresFor('m1', _source);
      expect(decodes, 2);
    });

    test('remembers an image with nothing to analyse', () async {
      var decodes = 0;
      final analyzer = CardFocusAnalyzer(
        decode: (_) async {
          decodes++;
          return (rgba: Uint8List(64), width: 4, height: 4);
        },
      );
      expect(await analyzer.rowScoresFor('m1', _source), isNull);
      expect(analyzer.hasAnswer('m1'), isTrue);
      await analyzer.rowScoresFor('m1', _source);
      expect(decodes, 1);
    });

    test('drops the oldest answers past its capacity', () async {
      final analyzer = CardFocusAnalyzer(
        decode: (_) async => _small(),
        capacity: 2,
      );
      await analyzer.rowScoresFor('a', _source);
      await analyzer.rowScoresFor('b', _source);
      await analyzer.rowScoresFor('c', _source);
      expect(analyzer.hasAnswer('a'), isFalse);
      expect(analyzer.hasAnswer('c'), isTrue);
    });

    test(
      'keeps the answers a card asked for again past its capacity',
      () async {
        final analyzer = CardFocusAnalyzer(
          decode: (_) async => _small(),
          capacity: 2,
        );
        await analyzer.rowScoresFor('a', _source);
        await analyzer.rowScoresFor('b', _source);
        // 'a' is read again, so 'b' is now the one no card has asked for
        // longest.
        await analyzer.rowScoresFor('a', _source);
        await analyzer.rowScoresFor('c', _source);
        expect(analyzer.hasAnswer('a'), isTrue);
        expect(analyzer.hasAnswer('b'), isFalse);
        expect(analyzer.hasAnswer('c'), isTrue);
      },
    );

    test('runs at most two decodes at once', () async {
      var running = 0;
      var peak = 0;
      final gates = <Completer<SmallImage?>>[];
      final analyzer = CardFocusAnalyzer(
        decode: (_) {
          running++;
          if (running > peak) peak = running;
          final gate = Completer<SmallImage?>();
          gates.add(gate);
          return gate.future.whenComplete(() => running--);
        },
      );
      final all = [
        for (final k in ['a', 'b', 'c', 'd']) analyzer.rowScoresFor(k, _source),
      ];
      // Release decodes as they start until all four are done.
      var released = 0;
      while (released < 4) {
        await Future<void>.delayed(Duration.zero);
        if (gates.length > released) {
          gates[released++].complete(_small());
        }
      }
      await Future.wait(all);
      expect(peak, 2);
    });

    test('a timed-out decode answers null but keeps its slot until it '
        'settles', () async {
      final gates = <String, Completer<SmallImage?>>{};
      final analyzer = CardFocusAnalyzer(
        decodeTimeout: const Duration(milliseconds: 20),
        decode: (source) {
          final key = (source as MemoryImage).bytes.first.toString();
          return (gates[key] = Completer<SmallImage?>()).future;
        },
      );
      MemoryImage image(int id) => MemoryImage(Uint8List.fromList([id]));

      final slow = [
        analyzer.rowScoresFor('a', image(1)),
        analyzer.rowScoresFor('b', image(2)),
      ];
      final third = analyzer.rowScoresFor('c', image(3));

      // Both callers hear null once the timeout passes...
      expect(await Future.wait(slow), [null, null]);
      // ...but their decodes are still running, so the third has not
      // started: two at once, still.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(gates.keys, unorderedEquals(['1', '2']));

      // One settles, late: its slot goes to the third.
      gates['1']!.complete(_small());
      await Future<void>.delayed(Duration.zero);
      expect(gates.keys, contains('3'));
      gates['3']!.complete(_small());
      expect(await third, hasLength(4));
      // A late answer is not remembered: it may come in time next time.
      expect(analyzer.hasAnswer('a'), isFalse);
    });

    test('a decode that throws frees its slot', () async {
      var calls = 0;
      final analyzer = CardFocusAnalyzer(
        decode: (_) {
          calls++;
          if (calls <= 2) throw StateError('broken');
          return Future.value(_small());
        },
      );

      expect(await analyzer.rowScoresFor('a', _source), isNull);
      expect(await analyzer.rowScoresFor('b', _source), isNull);
      expect(await analyzer.rowScoresFor('c', _source), hasLength(4));
    });
  });
}
