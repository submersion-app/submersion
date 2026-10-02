import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

/// `DiveStatistics.divesThisYear` (issue #2600): the count of dives dated in
/// the current calendar year, shown beside the lifetime per-year average so
/// the average is never mistaken for this year's total.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final created = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  /// Dive times are stored as wall clock encoded as UTC, so the fixture
  /// builds them with `DateTime.utc`.
  Future<void> dive(String id, DateTime wallClock, {String? diverId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(wallClock.millisecondsSinceEpoch),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
  }

  Future<DiveStatistics> statsIn2026({
    DiveFilterState filter = const DiveFilterState(),
  }) {
    return withClock(
      Clock.fixed(DateTime(2026, 7, 15, 12)),
      () => repo.getStatistics(filter: filter),
    );
  }

  test('counts only dives dated in the current calendar year', () async {
    await dive('last-year-end', DateTime.utc(2025, 12, 31, 23, 59));
    await dive('year-start', DateTime.utc(2026, 1, 1));
    await dive('mid-year', DateTime.utc(2026, 7, 4, 10));
    await dive('year-end', DateTime.utc(2026, 12, 31, 23, 59));
    await dive('next-year-start', DateTime.utc(2027, 1, 1));

    final stats = await statsIn2026();

    expect(stats.totalDives, 5);
    expect(stats.divesThisYear, 3);
  });

  test('is zero when no dive falls in the current year', () async {
    await dive('old', DateTime.utc(2024, 3, 3));

    final stats = await statsIn2026();

    expect(stats.totalDives, 1);
    expect(stats.divesThisYear, 0);
  });

  test('honors the active filter like the other aggregates', () async {
    await dive('this-year-deep', DateTime.utc(2026, 2, 2));
    await dive('this-year-shallow', DateTime.utc(2026, 3, 3));
    await dive('last-year', DateTime.utc(2025, 3, 3));
    await (db.update(db.dives)..where((t) => t.id.isIn(['this-year-deep'])))
        .write(const DivesCompanion(maxDepth: Value(40.0)));
    await (db.update(db.dives)
          ..where((t) => t.id.isIn(['this-year-shallow', 'last-year'])))
        .write(const DivesCompanion(maxDepth: Value(10.0)));

    final stats = await statsIn2026(
      filter: const DiveFilterState(minDepth: 30),
    );

    expect(stats.totalDives, 1);
    expect(stats.divesThisYear, 1);
  });

  test('scopes to the requested diver', () async {
    final at = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;
    for (final id in ['diver1', 'diver2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    }
    await dive('mine', DateTime.utc(2026, 5, 5), diverId: 'diver1');
    await dive('theirs', DateTime.utc(2026, 5, 5), diverId: 'diver2');

    final stats = await withClock(
      Clock.fixed(DateTime(2026, 7, 15, 12)),
      () => repo.getStatistics(diverId: 'diver1'),
    );

    expect(stats.divesThisYear, 1);
  });
}
