import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.sac uses effectiveRuntime', () {
    test('calculates SAC using runtime, not bottomTime (issue #72)', () {
      // Reproduce issue #72: 170 bar used, AL80 (11.1L), avg depth 20.3m, runtime 42 min
      final dive = Dive(
        id: 'issue-72',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'AL80',
            volume: 11.1,
            startPressure: 200,
            endPressure: 30,
          ),
        ],
      );
      // (200-30) * 11.1 / 42 / (20.3/10 + 1) = 1887 / 42 / 3.03 = 14.83
      expect(dive.sac!, closeTo(14.83, 0.1));
    });

    test('calculates sacPressure using runtime (issue #72)', () {
      final dive = Dive(
        id: 'issue-72-p',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'AL80',
            volume: 11.1,
            startPressure: 200,
            endPressure: 30,
          ),
        ],
      );
      // (200-30) / 42 / 3.03 = 1.336
      expect(dive.sacPressure!, closeTo(1.34, 0.1));
    });

    test('falls back to bottomTime when runtime unavailable', () {
      final dive = Dive(
        id: 'fallback',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 30),
        avgDepth: 20.0,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Tank',
            volume: 12.0,
            startPressure: 200,
            endPressure: 50,
          ),
        ],
      );
      // (200-50) * 12 / 30 / 3 = 20.0
      expect(dive.sac!, closeTo(20.0, 0.1));
    });

    test('returns null when no time source available', () {
      final dive = Dive(
        id: 'no-time',
        dateTime: DateTime(2024, 1, 1),
        avgDepth: 20.0,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Tank',
            volume: 12.0,
            startPressure: 200,
            endPressure: 50,
          ),
        ],
      );
      expect(dive.sac, isNull);
    });
  });
}
