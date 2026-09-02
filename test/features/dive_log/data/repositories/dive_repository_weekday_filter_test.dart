import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

/// Dives reach the DB through `createDive`, which writes
/// `dive.dateTime.millisecondsSinceEpoch` verbatim into the wall-clock-as-UTC
/// `dive_date_time` column. The fixtures therefore build UTC-flagged dives, as
/// the app does: a LOCAL DateTime here would store a wall clock shifted by the
/// machine's UTC offset and land on a different weekday under some zones
/// (issue #1368). Filter dates stay LOCAL, which is what the pickers produce.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('SQL filter matches ANY selected weekday', () async {
    // 28 days apart (4 whole weeks) guarantees the same weekday regardless
    // of which actual day of the week these calendar dates land on.
    final mondayA = DateTime.utc(2026, 6, 8);
    final mondayB = DateTime.utc(2026, 7, 6);
    final tuesday = DateTime.utc(2026, 6, 9);
    await repository.createDive(domain.Dive(id: 'd1', dateTime: mondayA));
    await repository.createDive(domain.Dive(id: 'd2', dateTime: mondayB));
    await repository.createDive(domain.Dive(id: 'd3', dateTime: tuesday));

    final results = await repository.getDiveSummaries(
      filter: DiveFilterState(weekdays: [mondayA.weekday]),
    );
    final ids = results.map((d) => d.id).toSet();
    expect(ids, {'d1', 'd2'});
  });

  test('SQL filter ANDs weekday with date range', () async {
    final mondayInRange = DateTime.utc(2026, 6, 8);
    final mondayOutOfRange = DateTime.utc(2026, 7, 6);
    final tuesdayInRange = DateTime.utc(2026, 6, 9);
    await repository.createDive(domain.Dive(id: 'd1', dateTime: mondayInRange));
    await repository.createDive(
      domain.Dive(id: 'd2', dateTime: mondayOutOfRange),
    );
    await repository.createDive(
      domain.Dive(id: 'd3', dateTime: tuesdayInRange),
    );

    final results = await repository.getDiveSummaries(
      filter: DiveFilterState(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        weekdays: [mondayInRange.weekday],
      ),
    );
    expect(results.map((d) => d.id).toSet(), {'d1'});
  });

  test('in-memory apply() matches by weekday membership', () {
    final monday = DateTime.utc(2026, 6, 8);
    final tuesday = DateTime.utc(2026, 6, 9);
    final dives = [
      domain.Dive(id: 'a', dateTime: monday),
      domain.Dive(id: 'b', dateTime: tuesday),
    ];
    final filtered = DiveFilterState(weekdays: [monday.weekday]).apply(dives);
    expect(filtered.map((d) => d.id), ['a']);
  });
}
