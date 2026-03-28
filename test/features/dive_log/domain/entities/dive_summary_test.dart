import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

void main() {
  group('DiveSummary', () {
    final now = DateTime(2026, 3, 28, 10, 0);
    final entryTime = DateTime(2026, 3, 28, 10, 5);

    DiveSummary makeSummary({Duration? bottomTime, Duration? runtime}) {
      return DiveSummary(
        id: 'dive-1',
        diveNumber: 42,
        dateTime: now,
        entryTime: entryTime,
        maxDepth: 25.3,
        bottomTime: bottomTime ?? const Duration(minutes: 45),
        runtime: runtime ?? const Duration(minutes: 50),
        waterTemp: 22.0,
        rating: 4,
        isFavorite: true,
        diveTypeId: 'recreational',
        siteName: 'Blue Hole',
        siteCountry: 'Belize',
        siteRegion: 'Lighthouse Reef',
        sortTimestamp: entryTime.millisecondsSinceEpoch,
      );
    }

    test('constructor stores bottomTime and runtime', () {
      final summary = makeSummary();
      expect(summary.bottomTime, const Duration(minutes: 45));
      expect(summary.runtime, const Duration(minutes: 50));
    });

    test('constructor allows null bottomTime', () {
      final summary = DiveSummary(
        id: 'dive-2',
        dateTime: now,
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      expect(summary.bottomTime, isNull);
    });

    group('fromDive', () {
      test('maps bottomTime from Dive', () {
        final dive = Dive(
          id: 'dive-1',
          diveNumber: 42,
          dateTime: now,
          entryTime: entryTime,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.3,
          waterTemp: 22.0,
          rating: 4,
          isFavorite: true,
          diveTypeId: 'recreational',
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        );

        final summary = DiveSummary.fromDive(dive);

        expect(summary.bottomTime, const Duration(minutes: 45));
        expect(summary.runtime, const Duration(minutes: 50));
        expect(summary.id, 'dive-1');
        expect(summary.diveNumber, 42);
        expect(summary.maxDepth, 25.3);
      });

      test('maps null bottomTime from Dive', () {
        final dive = Dive(
          id: 'dive-2',
          dateTime: now,
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        );

        final summary = DiveSummary.fromDive(dive);
        expect(summary.bottomTime, isNull);
        expect(summary.runtime, isNull);
      });
    });

    group('copyWith', () {
      test('preserves bottomTime when not overridden', () {
        final original = makeSummary();
        final copy = original.copyWith(rating: 5);

        expect(copy.bottomTime, const Duration(minutes: 45));
        expect(copy.runtime, const Duration(minutes: 50));
        expect(copy.rating, 5);
      });

      test('overrides bottomTime', () {
        final original = makeSummary();
        final copy = original.copyWith(bottomTime: const Duration(minutes: 30));

        expect(copy.bottomTime, const Duration(minutes: 30));
        expect(copy.runtime, const Duration(minutes: 50));
      });

      test('overrides runtime', () {
        final original = makeSummary();
        final copy = original.copyWith(runtime: const Duration(minutes: 55));

        expect(copy.bottomTime, const Duration(minutes: 45));
        expect(copy.runtime, const Duration(minutes: 55));
      });
    });

    group('equality', () {
      test('equal when bottomTime matches', () {
        final a = makeSummary();
        final b = makeSummary();
        expect(a, equals(b));
      });

      test('not equal when bottomTime differs', () {
        final a = makeSummary(bottomTime: const Duration(minutes: 45));
        final b = makeSummary(bottomTime: const Duration(minutes: 30));
        expect(a, isNot(equals(b)));
      });

      test('not equal when runtime differs', () {
        final a = makeSummary(runtime: const Duration(minutes: 50));
        final b = makeSummary(runtime: const Duration(minutes: 55));
        expect(a, isNot(equals(b)));
      });
    });
  });
}
