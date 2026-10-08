import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/services/shared_gear_overlap_rules.dart';

/// Rules for gear on two profiles' overlapping dives (issue #2853).
void main() {
  final t0 = DateTime.utc(2026, 5, 1, 10);
  DateTime m(int minutes) => t0.add(Duration(minutes: minutes));

  group('gearUseOverlaps', () {
    test('6 minutes shared overlaps', () {
      expect(
        gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(34), bEnd: m(80)),
        isTrue,
      );
    });
    test('exactly 5 minutes shared does not', () {
      expect(
        gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(35), bEnd: m(80)),
        isFalse,
      );
    });
    test('4 minutes shared does not', () {
      expect(
        gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(36), bEnd: m(80)),
        isFalse,
      );
    });
    test('one dive inside the other overlaps', () {
      expect(
        gearUseOverlaps(aStart: m(0), aEnd: m(60), bStart: m(10), bEnd: m(30)),
        isTrue,
      );
    });
    test('disjoint dives do not', () {
      expect(
        gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(60), bEnd: m(90)),
        isFalse,
      );
    });
  });

  group('foldToTopmost', () {
    test('a lone item is its own top', () {
      expect(foldToTopmost({'light': {}}), {'light': <String>{}});
    });
    test('parts fold into their matched host', () {
      expect(
        foldToTopmost({
          'reg': {},
          'hose': {'reg'},
          'octo': {'reg'},
        }),
        {
          'reg': {'hose', 'octo'},
        },
      );
    });
    test('a chain folds to its root', () {
      expect(
        foldToTopmost({
          'ccr': {},
          'head': {'ccr'},
          'cell': {'head'},
        }),
        {
          'ccr': {'head', 'cell'},
        },
      );
    });
    test('a host not matched is ignored', () {
      expect(
        foldToTopmost({
          'hose': {'reg'},
        }),
        {'hose': <String>{}},
      );
    });
    test('a cycle terminates on its smallest id', () {
      expect(
        foldToTopmost({
          'b': {'a'},
          'a': {'b'},
        }),
        {
          'a': {'b'},
        },
      );
    });
    test('an item leading into a cycle folds under the cycle', () {
      expect(
        foldToTopmost({
          'a': {'c'},
          'c': {'d'},
          'd': {'c'},
        }),
        {
          'c': {'a', 'd'},
        },
      );
    });
  });

  group('sharedGearExit', () {
    test('the recorded exit wins', () {
      expect(
        sharedGearExit(
          entry: m(0),
          exit: m(30),
          runtime: const Duration(minutes: 40),
        ),
        m(30),
      );
    });
    test('then entry plus runtime, then plus bottom time', () {
      expect(
        sharedGearExit(entry: m(0), runtime: const Duration(minutes: 40)),
        m(40),
      );
      expect(
        sharedGearExit(entry: m(0), bottomTime: const Duration(minutes: 35)),
        m(35),
      );
    });
    test('no duration gives no exit', () {
      expect(sharedGearExit(entry: m(0)), isNull);
    });
  });
}
