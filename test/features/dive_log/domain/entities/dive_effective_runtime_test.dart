import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.effectiveRuntime', () {
    test('returns runtime when set', () {
      final dive = Dive(
        id: 'test-1',
        dateTime: DateTime(2024, 1, 1),
        runtime: const Duration(minutes: 42),
        bottomTime: const Duration(minutes: 30),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 45),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 42));
    });

    test('falls back to exitTime - entryTime when runtime is null', () {
      final dive = Dive(
        id: 'test-2',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 42),
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 42));
    });

    test('falls back to profile-based runtime when entry/exit are null', () {
      final dive = Dive(
        id: 'test-3',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 30),
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0),
          const DiveProfilePoint(timestamp: 600, depth: 20.0),
          const DiveProfilePoint(timestamp: 2520, depth: 0),
        ],
      );
      expect(dive.effectiveRuntime, const Duration(seconds: 2520));
    });

    test('falls back to bottomTime as last resort', () {
      final dive = Dive(
        id: 'test-4',
        dateTime: DateTime(2024, 1, 1),
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    test('returns null when nothing is available', () {
      final dive = Dive(id: 'test-5', dateTime: DateTime(2024, 1, 1));
      expect(dive.effectiveRuntime, isNull);
    });

    test('prefers runtime over entry/exit calculation', () {
      final dive = Dive(
        id: 'test-6',
        dateTime: DateTime(2024, 1, 1),
        runtime: const Duration(minutes: 40),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 50),
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 40));
    });

    test('skips entry/exit when only entryTime is set', () {
      final dive = Dive(
        id: 'test-7',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });
  });
}
