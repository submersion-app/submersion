import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../helpers/test_database.dart';

/// Issue #1368: `dives.dive_date_time` holds a wall clock flagged as UTC,
/// while every producer of a filter date builds a LOCAL `DateTime` (the
/// presets in the filter sheet, and `showAppDatePicker` by construction).
/// Comparing the two frames put the day boundary off by the device's UTC
/// offset, so a dive within that offset of a boundary was silently in or out
/// of the range.
///
/// The date axis has three implementations that must agree: the statistics
/// SQL subquery, the paginated dive list's WHERE builder, and the in-memory
/// `apply()` used by export/table/map views. This pins all three against the
/// same fixtures.
///
/// CI runs in UTC, where the offset is zero and the original bug cannot
/// reproduce, so the boundary-getter group deliberately feeds filter dates
/// that CARRY a time-of-day: that is the shape a non-zero offset produces,
/// and it fails under UTC too. The `.github/workflows/ci.yaml` timezone job
/// additionally replays this file under a whole-hour and a half-hour zone.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  // Wall clocks, as the entity and the column carry them. The four fixtures
  // straddle the two boundaries of a 2026-01-01..2026-06-30 range by less
  // than any real UTC offset.
  final justInsideStart = DateTime.utc(2026, 1, 1, 2, 0);
  final justBeforeStart = DateTime.utc(2025, 12, 31, 22, 0);
  final justInsideEnd = DateTime.utc(2026, 6, 30, 23, 30);
  final justAfterEnd = DateTime.utc(2026, 7, 1, 0, 0);

  // The dates a producer hands the filter: LOCAL midnights, exactly what the
  // presets and the date picker build.
  final rangeStart = DateTime(2026, 1, 1);
  final rangeEnd = DateTime(2026, 6, 30);

  DiveFilterState rangeFilter() =>
      DiveFilterState(startDate: rangeStart, endDate: rangeEnd);

  List<domain.Dive> allDives() => [
    domain.Dive(id: 'just-inside-start', dateTime: justInsideStart),
    domain.Dive(id: 'just-before-start', dateTime: justBeforeStart),
    domain.Dive(id: 'just-inside-end', dateTime: justInsideEnd),
    domain.Dive(id: 'just-after-end', dateTime: justAfterEnd),
  ];

  Future<void> seedDives() async {
    for (final dive in allDives()) {
      await repository.createDive(dive);
    }
  }

  Future<Set<String>> subqueryIdsMatching(DiveFilterState filter) async {
    final f = buildFilteredDiveIdSubquery(filter);
    final sql = f.subquery.isEmpty ? 'SELECT id FROM dives' : f.subquery;
    final rows = await db
        .customSelect(sql, variables: f.params.map((p) => Variable(p)).toList())
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  group('boundary getters', () {
    test('a null date leaves its bound null', () {
      const filter = DiveFilterState();
      expect(filter.startDateBoundMs, isNull);
      expect(filter.endDateBoundMs, isNull);
    });

    test('startDateBoundMs is the start of the calendar day', () {
      expect(
        DiveFilterState(startDate: rangeStart).startDateBoundMs,
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
    });

    test('startDateBoundMs discards a time-of-day component', () {
      // A local midnight west of UTC arrives here as an instant with a
      // non-zero UTC time-of-day. That component is the bug: it must not
      // reach the comparison.
      expect(
        DiveFilterState(
          startDate: DateTime.utc(2026, 1, 1, 5, 0),
        ).startDateBoundMs,
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
      expect(
        DiveFilterState(
          startDate: DateTime.utc(2026, 1, 1, 23, 59, 59, 999),
        ).startDateBoundMs,
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
    });

    test('endDateBoundMs is exclusive: the start of the day AFTER endDate', () {
      expect(
        DiveFilterState(endDate: rangeEnd).endDateBoundMs,
        DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
      );
    });

    test('endDateBoundMs discards a time-of-day component', () {
      expect(
        DiveFilterState(
          endDate: DateTime.utc(2026, 6, 30, 13, 30),
        ).endDateBoundMs,
        DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
      );
    });
  });

  group('apply()', () {
    test('keeps the whole start day and excludes the day before', () {
      final ids = rangeFilter().apply(allDives()).map((d) => d.id).toSet();
      expect(
        ids,
        contains('just-inside-start'),
        reason: '02:00 on the start day is inside a range starting that day',
      );
      expect(
        ids,
        isNot(contains('just-before-start')),
        reason: '22:00 the previous day is outside it',
      );
    });

    test('keeps the whole end day and excludes the day after', () {
      final ids = rangeFilter().apply(allDives()).map((d) => d.id).toSet();
      expect(
        ids,
        contains('just-inside-end'),
        reason: '23:30 on the end day is inside a range ending that day',
      );
      expect(
        ids,
        isNot(contains('just-after-end')),
        reason: 'midnight the following day is outside it',
      );
    });

    test('a local-frame dive is matched on its calendar day too', () {
      // apply() is public and takes whatever entities a caller holds, so it
      // compares calendar days rather than instants: a dive whose DateTime
      // was built local reads the same digits the diver sees.
      final localDive = domain.Dive(
        id: 'local',
        dateTime: DateTime(2026, 1, 1, 2, 0),
      );
      expect(rangeFilter().apply([localDive]).map((d) => d.id), ['local']);
    });
  });

  group('statistics SQL subquery', () {
    test('matches apply() on both boundaries', () async {
      await seedDives();
      expect(await subqueryIdsMatching(rangeFilter()), {
        'just-inside-start',
        'just-inside-end',
      });
    });

    test('binds the shared bounds, half-open', () {
      final f = buildFilteredDiveIdSubquery(rangeFilter());
      expect(f.subquery, contains('dive_date_time >= ?'));
      expect(
        f.subquery,
        contains('dive_date_time < ?'),
        reason: 'the end bound is the exclusive start of the following day',
      );
      expect(f.params.take(2), [
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
      ]);
    });
  });

  group('paginated dive list SQL', () {
    test('matches apply() on both boundaries', () async {
      await seedDives();
      final results = await repository.getDiveSummaries(filter: rangeFilter());
      expect(results.map((d) => d.id).toSet(), {
        'just-inside-start',
        'just-inside-end',
      });
    });
  });

  test('all three paths agree on an open-ended range', () async {
    await seedDives();
    final filter = DiveFilterState(startDate: rangeStart);
    final expected = {'just-inside-start', 'just-inside-end', 'just-after-end'};
    expect(filter.apply(allDives()).map((d) => d.id).toSet(), expected);
    expect(await subqueryIdsMatching(filter), expected);
    expect(
      (await repository.getDiveSummaries(
        filter: filter,
      )).map((d) => d.id).toSet(),
      expected,
    );
  });
}
