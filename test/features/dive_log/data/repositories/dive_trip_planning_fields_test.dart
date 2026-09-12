import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A dive loaded with its trip carries the trip's planning overrides
/// (expected dives and runtime), on both the single-dive and list reads.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Red Sea',
            startDate: DateTime(2026, 6, 1).millisecondsSinceEpoch,
            endDate: DateTime(2026, 6, 8).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            expectedDives: const Value(12),
            expectedRuntimeMinutes: const Value(75),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 6, 2).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(tripId: const Value('t1')),
        );
  });
  tearDown(tearDownTestDatabase);

  test('the single-dive read keeps the trip planning fields', () async {
    final trip = (await DiveRepository().getDiveById('d1'))!.trip!;
    expect(trip.expectedDives, 12);
    expect(trip.expectedRuntimeMinutes, 75);
  });

  test('the list read keeps the trip planning fields', () async {
    final trip = (await DiveRepository().getAllDives()).single.trip!;
    expect(trip.expectedDives, 12);
    expect(trip.expectedRuntimeMinutes, 75);
  });
}
