import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_history_repository.dart';

import '../../../../helpers/test_database.dart';

/// The two history reads behind the scrubber margin estimates, both scoped
/// to what happened before a given instant so a past trip reads as of
/// its start.
void main() {
  late AppDatabase db;
  late TripHistoryRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TripHistoryRepository(db: db);
  });
  tearDown(tearDownTestDatabase);

  Future<void> trip(String id, DateTime start, DateTime end) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: start.millisecondsSinceEpoch,
          endDate: end.millisecondsSinceEpoch,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> dive(
    String id,
    DateTime at, {
    String? tripId,
    String? diverId,
    String mode = 'oc',
    int? runtime = 3600,
    int? bottomTime,
    double? scrubber,
    int summaryStamp = 1,
    int summaryVersion = DiveSensorSummaryService.version,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            // Stored as the app stores dives: the wall clock, in UTC.
            diveDateTime: DateTime.utc(
              at.year,
              at.month,
              at.day,
              at.hour,
              at.minute,
            ).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            tripId: Value(tripId),
            diverId: Value(diverId),
            diveMode: Value(mode),
            runtime: Value(runtime),
            bottomTime: Value(bottomTime),
          ),
        );
    if (scrubber != null) {
      await db
          .into(db.diveSensorSummaries)
          .insert(
            DiveSensorSummariesCompanion.insert(
              diveId: id,
              engineVersion: summaryVersion,
              sourceUpdatedAt: summaryStamp,
              computedAt: 1,
            ).copyWith(scrubberConsumedMinutes: Value(scrubber)),
          );
    }
  }

  test('dives per dive day over the recent trips, newest first', () async {
    await trip('t1', DateTime(2025, 1, 1), DateTime(2025, 1, 5));
    await trip('t2', DateTime(2025, 6, 1), DateTime(2025, 6, 3));
    await trip('t3', DateTime(2025, 9, 1), DateTime(2025, 9, 2));
    await trip('later', DateTime(2026, 7, 1), DateTime(2026, 7, 5));
    await trip('empty', DateTime(2025, 3, 1), DateTime(2025, 3, 3));
    // t1: 4 dives on 2 days.
    await dive('a', DateTime(2025, 1, 1, 9), tripId: 't1');
    await dive('b', DateTime(2025, 1, 1, 14), tripId: 't1');
    await dive('c', DateTime(2025, 1, 2, 9), tripId: 't1');
    await dive('d', DateTime(2025, 1, 2, 14), tripId: 't1');
    // t2: 3 dives on 1 day.
    await dive('e', DateTime(2025, 6, 1, 9), tripId: 't2');
    await dive('f', DateTime(2025, 6, 1, 12), tripId: 't2');
    await dive('g', DateTime(2025, 6, 1, 15), tripId: 't2');
    // t3: 1 dive.
    await dive('h', DateTime(2025, 9, 1, 9), tripId: 't3');
    // A trip after the cut-off is not history.
    await dive('i', DateTime(2026, 7, 1, 9), tripId: 'later');

    final figures = await repo.divesPerDiveDay(before: DateTime(2026, 6, 1));
    expect(figures, [1, 3, 2]);
    final two = await repo.divesPerDiveDay(
      before: DateTime(2026, 6, 1),
      limit: 2,
    );
    expect(two, [1, 3]);
  });

  test('recent CCR figures keep the summary minutes and the runtime', () async {
    await dive('oc', DateTime(2026, 1, 1), mode: 'oc', scrubber: 99);
    await dive(
      'c1',
      DateTime(2026, 1, 2),
      mode: 'ccr',
      runtime: 3600,
      scrubber: 40,
    );
    await dive('c2', DateTime(2026, 1, 3), mode: 'scr', runtime: 4200);
    await dive(
      'c3',
      DateTime(2026, 2, 1),
      mode: 'ccr',
      runtime: 3000,
      scrubber: 55,
    );
    await dive('after', DateTime(2026, 9, 1), mode: 'ccr', scrubber: 10);

    final figures = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
    );
    expect(figures.map((f) => f.scrubberMinutes), [55, null, 40]);
    expect(figures.map((f) => f.runtimeMinutes), [50, 70, 60]);
    final one = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
      limit: 1,
    );
    expect(one.single.scrubberMinutes, 55);
  });

  test('a stale summary gives way to the runtime', () async {
    // A summary built before the dive's last edit, or by an older engine,
    // describes a dive that no longer exists. Its scrubber minutes must
    // not reach the median while the rebuild is pending.
    await dive(
      'edited',
      DateTime(2026, 1, 2),
      mode: 'ccr',
      scrubber: 40,
      summaryStamp: 0,
    );
    await dive(
      'old-engine',
      DateTime(2026, 1, 3),
      mode: 'ccr',
      scrubber: 45,
      summaryVersion: DiveSensorSummaryService.version - 1,
    );
    await dive('current', DateTime(2026, 1, 4), mode: 'ccr', scrubber: 50);

    final figures = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
    );
    expect(figures.map((f) => f.scrubberMinutes), [50, null, null]);
    expect(figures.map((f) => f.runtimeMinutes), [60, 60, 60]);
  });

  test('a zero or negative duration is no figure at all', () async {
    // A zero runtime from a manual entry would drag the runtime median
    // toward zero; the next positive figure (bottom time) stands in, and a
    // dive with neither has no figure.
    await dive('zero', DateTime(2026, 1, 2), mode: 'ccr', runtime: 0);
    await dive(
      'fallback',
      DateTime(2026, 1, 3),
      mode: 'ccr',
      runtime: 0,
      bottomTime: 2400,
    );
    await dive('negative', DateTime(2026, 1, 4), mode: 'ccr', runtime: -60);

    final figures = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
    );
    expect(figures.map((f) => f.runtimeMinutes), [null, 40, null]);
  });

  test('a zero or negative scrubber figure is no figure at all', () async {
    // A stored zero would become the scrubber median and suppress the
    // runtime fallback, understating expected use.
    await dive('zero', DateTime(2026, 1, 2), mode: 'ccr', scrubber: 0);
    await dive('negative', DateTime(2026, 1, 3), mode: 'ccr', scrubber: -5);
    await dive('real', DateTime(2026, 1, 4), mode: 'ccr', scrubber: 42);
    final figures = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
    );
    expect(figures.map((f) => f.scrubberMinutes), [42, null, null]);
    expect(figures.map((f) => f.runtimeMinutes), [60, 60, 60]);
  });

  test('the cut-off is the calendar day, in any zone', () async {
    // Dives are stored as wall clock in UTC, the trip start as a local
    // midnight. The evening before counts as history; the first morning
    // does not. CI runs in UTC; run under another TZ to discriminate.
    await dive('eve', DateTime.utc(2026, 5, 31, 22), mode: 'ccr');
    await dive('dawn', DateTime.utc(2026, 6, 1, 1), mode: 'ccr');
    final figures = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
    );
    expect(figures, hasLength(1));
  });

  test('a loop dive without a runtime falls back, and is never zero', () async {
    // A hand-logged loop dive may carry only its bottom time; the rest of
    // the app reads runtime ?? bottomTime as the dive's length. A dive
    // with neither has no length to offer, and a zero would drag the
    // median down and understate the expected scrubber use.
    await dive(
      'bt',
      DateTime(2026, 1, 2),
      mode: 'ccr',
      runtime: null,
      bottomTime: 2400,
    );
    await dive('none', DateTime(2026, 1, 3), mode: 'ccr', runtime: null);
    final figures = await repo.recentRebreatherFigures(
      before: DateTime(2026, 6, 1),
    );
    expect(figures.map((f) => f.runtimeMinutes), [null, 40]);
  });

  group('shared trips', () {
    Future<void> diver(String id) => db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
        );

    test('counts only the requested diver\'s dives on a shared trip', () async {
      await diver('me');
      await diver('buddy');
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: 'shared',
              name: 'shared',
              startDate: DateTime(2025, 1, 1).millisecondsSinceEpoch,
              endDate: DateTime(2025, 1, 3).millisecondsSinceEpoch,
              createdAt: 1,
              updatedAt: 1,
            ).copyWith(diverId: const Value('me')),
          );
      // Two of mine on one day, four of my buddy's across two.
      await dive(
        'm1',
        DateTime(2025, 1, 1, 9),
        tripId: 'shared',
        diverId: 'me',
      );
      await dive(
        'm2',
        DateTime(2025, 1, 1, 14),
        tripId: 'shared',
        diverId: 'me',
      );
      for (final (i, at) in [
        DateTime(2025, 1, 1, 10),
        DateTime(2025, 1, 1, 15),
        DateTime(2025, 1, 2, 10),
        DateTime(2025, 1, 2, 15),
      ].indexed) {
        await dive('b$i', at, tripId: 'shared', diverId: 'buddy');
      }

      // Mine: 2 dives on 1 day. Counting the buddy's would give 6 over 2.
      expect(
        await repo.divesPerDiveDay(diverId: 'me', before: DateTime(2026)),
        [2],
      );
      expect(
        await repo.divesPerDiveDay(diverId: 'buddy', before: DateTime(2026)),
        [2],
      );
    });
  });
}
