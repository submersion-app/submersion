import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.effectiveRuntime', () {
    // --- Fallback chain priority tests ---

    test('returns runtime when set (highest priority)', () {
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

    test('prefers runtime over entry/exit even when shorter', () {
      final dive = Dive(
        id: 'test-priority',
        dateTime: DateTime(2024, 1, 1),
        runtime: const Duration(minutes: 40),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 50),
        bottomTime: const Duration(minutes: 30),
      );
      // runtime (40 min) takes priority over exit-entry (50 min)
      expect(dive.effectiveRuntime, const Duration(minutes: 40));
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

    // --- Entry/exit edge cases ---

    test('skips entry/exit when only entryTime is set', () {
      final dive = Dive(
        id: 'test-entry-only',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        bottomTime: const Duration(minutes: 30),
      );
      // Can't compute exit-entry → falls through to bottomTime
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    test('skips entry/exit when only exitTime is set', () {
      final dive = Dive(
        id: 'test-exit-only',
        dateTime: DateTime(2024, 1, 1),
        exitTime: DateTime(2024, 1, 1, 10, 42),
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    test('skips negative entry/exit difference (exit before entry)', () {
      final dive = Dive(
        id: 'test-negative',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 42),
        exitTime: DateTime(2024, 1, 1, 10, 0), // Before entry
        bottomTime: const Duration(minutes: 30),
      );
      // Negative difference → falls through to bottomTime
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    test('skips zero entry/exit difference (same time)', () {
      final dive = Dive(
        id: 'test-zero',
        dateTime: DateTime(2024, 1, 1),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 0), // Same as entry
        bottomTime: const Duration(minutes: 30),
      );
      // Zero duration → falls through to bottomTime
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    // --- Profile fallback edge cases ---

    test('skips profile when empty', () {
      final dive = Dive(
        id: 'test-empty-profile',
        dateTime: DateTime(2024, 1, 1),
        profile: const [],
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    test('skips profile with single point', () {
      final dive = Dive(
        id: 'test-single-point',
        dateTime: DateTime(2024, 1, 1),
        profile: [const DiveProfilePoint(timestamp: 0, depth: 10.0)],
        bottomTime: const Duration(minutes: 30),
      );
      expect(dive.effectiveRuntime, const Duration(minutes: 30));
    });

    // --- Null bottomTime fallback ---

    test('returns null when bottomTime is null and no other source', () {
      final dive = Dive(
        id: 'test-all-null',
        dateTime: DateTime(2024, 1, 1),
        profile: const [],
      );
      expect(dive.effectiveRuntime, isNull);
    });
  });
}
