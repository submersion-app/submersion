import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, TripsCompanion;
import 'package:submersion/features/trips/data/repositories/trip_date_stretch.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';

import '../../../../helpers/test_database.dart';

/// A trip stretches outward to cover its dives (issue #3351).
void main() {
  late AppDatabase db;
  late SyncRepository sync;
  const now = 5000;
  var diveCount = 0;

  setUp(() async {
    db = await setUpTestDatabase();
    sync = SyncRepository();
    diveCount = 0;
  });
  tearDown(tearDownTestDatabase);

  Future<void> addTrip(
    String id, {
    DateTime? start,
    DateTime? end,
    String? parent,
  }) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: (start ?? DateTime(2026, 3, 5)).millisecondsSinceEpoch,
          endDate: (end ?? DateTime(2026, 3, 10)).millisecondsSinceEpoch,
          parentTripId: Value(parent),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<String> addDive(String? tripId, DateTime at) async {
    final id = 'dive-${diveCount++}';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: at.millisecondsSinceEpoch,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    return id;
  }

  Future<({DateTime start, DateTime end, int updatedAt})> stored(
    String id,
  ) async {
    final row = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(id))).getSingle();
    return (
      start: DateTime.fromMillisecondsSinceEpoch(row.startDate),
      end: DateTime.fromMillisecondsSinceEpoch(row.endDate),
      updatedAt: row.updatedAt,
    );
  }

  Future<bool> staged(String id) async => (await sync.getPendingRecords()).any(
    (r) => r.entityType == 'trips' && r.recordId == id,
  );

  Future<List<TripDateStretch>> stretch(List<String> ids) =>
      stretchTripsToCoverDives(db, sync, ids, now: now);

  group('stretchTripsToCoverDives', () {
    test('a dive with no trip changes nothing', () async {
      await addTrip('t');
      final dive = await addDive(null, DateTime.utc(2026, 4, 1, 9));

      expect(await stretch([dive]), isEmpty);
      expect((await stored('t')).updatedAt, 1);
    });

    test('a covered dive writes nothing and stages nothing', () async {
      await addTrip('t');
      final dive = await addDive('t', DateTime.utc(2026, 3, 7, 9));

      expect(await stretch([dive]), isEmpty);
      expect((await stored('t')).updatedAt, 1);
      expect(await staged('t'), isFalse);
    });

    test('a dive outside stretches the trip and stages it', () async {
      await addTrip('t');
      final dive = await addDive('t', DateTime.utc(2026, 3, 14, 9));

      final result = await stretch([dive]);

      expect(result, [
        TripDateStretch(
          tripId: 't',
          tripName: 't',
          priorStart: DateTime(2026, 3, 5),
          priorEnd: DateTime(2026, 3, 10),
          start: DateTime(2026, 3, 5),
          end: DateTime(2026, 3, 14),
        ),
      ]);
      final row = await stored('t');
      expect(row.start, DateTime(2026, 3, 5));
      expect(row.end, DateTime(2026, 3, 14));
      expect(row.updatedAt, now);
      expect(await staged('t'), isTrue);
    });

    test('dives on two trips stretch both, each to its own dives', () async {
      await addTrip('a');
      await addTrip('b');
      final early = await addDive('a', DateTime.utc(2026, 3, 1, 9));
      final late = await addDive('b', DateTime.utc(2026, 3, 20, 9));

      await stretch([early, late]);

      expect((await stored('a')).start, DateTime(2026, 3, 1));
      expect((await stored('a')).end, DateTime(2026, 3, 10));
      expect((await stored('b')).start, DateTime(2026, 3, 5));
      expect((await stored('b')).end, DateTime(2026, 3, 20));
    });

    test('more dives than one chunk still count', () async {
      await addTrip('t');
      final ids = [
        for (var i = 0; i < 501; i++)
          await addDive('t', DateTime.utc(2026, 3, 7, 9)),
      ];
      ids.add(await addDive('t', DateTime.utc(2026, 3, 14, 9)));

      await stretch(ids);

      expect((await stored('t')).end, DateTime(2026, 3, 14));
    });

    test('a side trip that stretches stretches its larger trip', () async {
      await addTrip('parent');
      await addTrip('side', parent: 'parent');
      final dive = await addDive('side', DateTime.utc(2026, 3, 14, 9));

      final result = await stretch([dive]);

      expect(
        {for (final s in result) s.tripId: s.isLargerTrip},
        {'side': false, 'parent': true},
      );
      expect((await stored('parent')).end, DateTime(2026, 3, 14));
      expect(await staged('parent'), isTrue);
    });

    test('a dive inside a side trip leaves the larger trip alone', () async {
      await addTrip('parent');
      await addTrip(
        'side',
        start: DateTime(2026, 3, 12),
        end: DateTime(2026, 3, 16),
        parent: 'parent',
      );
      final dive = await addDive('side', DateTime.utc(2026, 3, 14, 9));

      expect(await stretch([dive]), isEmpty);
      expect((await stored('parent')).end, DateTime(2026, 3, 10));
    });

    test('a stretch that stays inside the larger trip stops there', () async {
      await addTrip(
        'parent',
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
      );
      await addTrip('side', parent: 'parent');
      final dive = await addDive('side', DateTime.utc(2026, 3, 14, 9));

      final result = await stretch([dive]);

      expect(result.map((s) => s.tripId), ['side']);
      expect((await stored('parent')).updatedAt, 1);
    });

    test('a link to a side trip counts as no larger trip', () async {
      await addTrip('root');
      await addTrip('middle', parent: 'root');
      await addTrip('side', parent: 'middle');
      final dive = await addDive('side', DateTime.utc(2026, 3, 14, 9));

      final result = await stretch([dive]);

      expect(result.map((s) => s.tripId), ['side']);
      expect((await stored('middle')).updatedAt, 1);
    });

    test('a larger trip takes its own dives and its side trip\'s', () async {
      await addTrip('parent');
      await addTrip('side', parent: 'parent');
      final own = await addDive('parent', DateTime.utc(2026, 3, 1, 9));
      final viaSide = await addDive('side', DateTime.utc(2026, 3, 14, 9));

      final result = await stretch([own, viaSide]);

      final parent = result.singleWhere((s) => s.tripId == 'parent');
      expect(parent.start, DateTime(2026, 3, 1));
      expect(parent.end, DateTime(2026, 3, 14));
      expect(parent.isLargerTrip, isFalse);
    });
  });

  group('restoreStretchedTripDates', () {
    Future<List<TripDateStretch>> stretched() async {
      await addTrip('t');
      return stretch([
        await addDive('t', DateTime.utc(2026, 3, 1, 9)),
        await addDive('t', DateTime.utc(2026, 3, 14, 9)),
      ]);
    }

    Future<void> setEnd(DateTime end) =>
        (db.update(db.trips)..where((t) => t.id.equals('t'))).write(
          TripsCompanion(endDate: Value(end.millisecondsSinceEpoch)),
        );

    test('puts both bounds back and stages the trip', () async {
      final stretches = await stretched();
      await sync.clearPendingRecords();

      await restoreStretchedTripDates(db, sync, stretches, now: now + 1);

      final row = await stored('t');
      expect(row.start, DateTime(2026, 3, 5));
      expect(row.end, DateTime(2026, 3, 10));
      expect(row.updatedAt, now + 1);
      expect(await staged('t'), isTrue);
    });

    test('leaves a bound the diver edited since', () async {
      final stretches = await stretched();
      await setEnd(DateTime(2026, 3, 12));

      await restoreStretchedTripDates(db, sync, stretches, now: now + 1);

      final row = await stored('t');
      expect(row.start, DateTime(2026, 3, 5));
      expect(row.end, DateTime(2026, 3, 12));
    });

    test('leaves a later stretch of that bound', () async {
      final stretches = await stretched();
      await stretch([await addDive('t', DateTime.utc(2026, 3, 20, 9))]);

      await restoreStretchedTripDates(db, sync, stretches, now: now + 1);

      final row = await stored('t');
      expect(row.start, DateTime(2026, 3, 5));
      expect(row.end, DateTime(2026, 3, 20));
    });

    test('writes nothing when no moved bound can return', () async {
      await addTrip('t');
      final stretches = await stretch([
        await addDive('t', DateTime.utc(2026, 3, 14, 9)),
      ]);
      await setEnd(DateTime(2026, 3, 12));
      await sync.clearPendingRecords();

      await restoreStretchedTripDates(db, sync, stretches, now: now + 1);

      expect((await stored('t')).updatedAt, now);
      expect(await staged('t'), isFalse);
    });

    test('puts a larger trip back with its side trip', () async {
      await addTrip('parent');
      await addTrip('side', parent: 'parent');
      final stretches = await stretch([
        await addDive('side', DateTime.utc(2026, 3, 14, 9)),
      ]);

      await restoreStretchedTripDates(db, sync, stretches, now: now + 1);

      expect((await stored('parent')).end, DateTime(2026, 3, 10));
      expect((await stored('side')).end, DateTime(2026, 3, 10));
    });

    test('a trip deleted since is skipped', () async {
      final stretches = await stretched();
      await db.customStatement('UPDATE dives SET trip_id = NULL');
      await (db.delete(db.trips)..where((t) => t.id.equals('t'))).go();

      await restoreStretchedTripDates(db, sync, stretches, now: now + 1);

      expect(await db.select(db.trips).get(), isEmpty);
    });
  });
}
