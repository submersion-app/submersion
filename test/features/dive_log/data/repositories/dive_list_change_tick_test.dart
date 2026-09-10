import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() => tearDownTestDatabase());

  Future<void> insertTrip(String id, String name) => db
      .into(db.trips)
      .insert(
        TripsCompanion(
          id: Value(id),
          name: Value(name),
          startDate: Value(now),
          endDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  /// Collects ticks for [window], so a stream that never fires is a real
  /// failure rather than a hang.
  Future<int> ticksDuring(
    Stream<void> stream,
    Future<void> Function() action,
  ) async {
    var count = 0;
    final sub = stream.listen((_) => count++);
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await sub.cancel();
    return count;
  }

  group('dive list change tick', () {
    test(
      'a trip rename ticks the list but not the dives-only stream',
      () async {
        await insertTrip('t1', 'Tassie');

        final listTicks = await ticksDuring(
          repository.watchDiveListChanges(),
          () => (db.update(db.trips)..where((t) => t.id.equals('t1'))).write(
            const TripsCompanion(name: Value('Tasmania')),
          ),
        );
        expect(
          listTicks,
          greaterThan(0),
          reason: 'the list renders the trip name, so it must reload',
        );

        await insertTrip('t2', 'Red Sea');
        final diveTicks = await ticksDuring(
          repository.watchDivesChanges(),
          () => (db.update(db.trips)..where((t) => t.id.equals('t2'))).write(
            const TripsCompanion(name: Value('Egypt')),
          ),
        );
        expect(
          diveTicks,
          0,
          reason: 'the dives-only tick is why the header used to go stale',
        );
      },
    );

    test('a safety finding ticks the list, which renders its badge', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('d9'),
              diveDateTime: Value(
                asWallClockUtc(DateTime(2026, 6, 8)).millisecondsSinceEpoch,
              ),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final listTicks = await ticksDuring(
        repository.watchDiveListChanges(),
        // The generated companion, not hand-written SQL: this table has no
        // updated_at, and a literal column list silently rots against the
        // schema.
        () => db
            .into(db.diveSafetyFindings)
            .insert(
              DiveSafetyFindingsCompanion(
                id: const Value('f1'),
                diveId: const Value('d9'),
                ruleId: const Value('ascent_rate'),
                severity: const Value('warning'),
                engineVersion: const Value(1),
                createdAt: Value(now),
              ),
            ),
      );

      expect(
        listTicks,
        greaterThan(0),
        reason: 'the row badge counts findings, so the list must reload',
      );
    });

    test('a dive write still ticks the list', () async {
      final ticks = await ticksDuring(
        repository.watchDiveListChanges(),
        () => db
            .into(db.dives)
            .insert(
              DivesCompanion(
                id: const Value('d1'),
                diveDateTime: Value(
                  asWallClockUtc(DateTime(2026, 6, 8)).millisecondsSinceEpoch,
                ),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            ),
      );
      expect(ticks, greaterThan(0));
    });
  });
}
