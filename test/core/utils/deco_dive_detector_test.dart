import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/deco_dive_detector.dart';

void main() {
  group('DecoDiveDetector', () {
    test('empty samples is not a deco dive', () {
      expect(DecoDiveDetector.isDecoDive(samples: const []), isFalse);
    });

    test('samples without deco indicators is not a deco dive', () {
      final samples = [
        const DecoDiveSample(depth: 1.0, ndl: 3600),
        const DecoDiveSample(depth: 18.0, ndl: 1200, ceiling: 0.0, tts: 120),
        const DecoDiveSample(depth: 5.0, ndl: 2400),
      ];
      expect(DecoDiveDetector.isDecoDive(samples: samples), isFalse);
    });

    test('a positive deco ceiling marks the dive as deco', () {
      final samples = [
        const DecoDiveSample(depth: 1.5, ceiling: 0.0),
        const DecoDiveSample(depth: 42.0, ceiling: 6.0),
      ];
      expect(DecoDiveDetector.isDecoDive(samples: samples), isTrue);
    });

    test('a deco stop sample (decoType 2) marks the dive as deco', () {
      final samples = [
        const DecoDiveSample(depth: 1.5, decoType: 0),
        const DecoDiveSample(depth: 6.0, decoType: 2),
      ];
      expect(DecoDiveDetector.isDecoDive(samples: samples), isTrue);
    });

    test('safety and deep stop samples do not mark the dive as deco', () {
      final samples = [
        const DecoDiveSample(depth: 15.0, decoType: 3),
        const DecoDiveSample(depth: 5.0, decoType: 1),
      ];
      expect(DecoDiveDetector.isDecoDive(samples: samples), isFalse);
    });

    test(
      'exhausted NDL with remaining TTS at depth marks the dive as deco',
      () {
        final samples = [
          const DecoDiveSample(depth: 30.0, ndl: 300, tts: 180),
          const DecoDiveSample(depth: 32.0, ndl: 0, tts: 600),
        ];
        expect(DecoDiveDetector.isDecoDive(samples: samples), isTrue);
      },
    );

    test('exhausted NDL at the surface is ignored', () {
      final samples = [
        const DecoDiveSample(depth: 0.0, ndl: 0, tts: 60),
        const DecoDiveSample(depth: 18.0, ndl: 1200),
      ];
      expect(DecoDiveDetector.isDecoDive(samples: samples), isFalse);
    });

    test('TTS alone (NDL still positive or absent) is not deco', () {
      final samples = [
        const DecoDiveSample(depth: 25.0, tts: 300, ndl: 900),
        const DecoDiveSample(depth: 25.0, tts: 320),
      ];
      expect(DecoDiveDetector.isDecoDive(samples: samples), isFalse);
    });

    test('a decoStopStart event marks the dive as deco', () {
      expect(
        DecoDiveDetector.isDecoDive(
          samples: const [],
          eventMaps: const [
            {'eventType': 'decoStopStart', 'timestamp': 1200},
          ],
        ),
        isTrue,
      );
    });

    test('a decoViolation event marks the dive as deco', () {
      expect(
        DecoDiveDetector.isDecoDive(
          samples: const [],
          eventMaps: const [
            {'eventType': 'decoViolation', 'timestamp': 1500},
          ],
        ),
        isTrue,
      );
    });

    test('unrelated events do not mark the dive as deco', () {
      expect(
        DecoDiveDetector.isDecoDive(
          samples: const [],
          eventMaps: const [
            {'eventType': 'safetyStopStart', 'timestamp': 1200},
            {'eventType': 'bookmark', 'timestamp': 300},
          ],
        ),
        isFalse,
      );
    });
  });
}
