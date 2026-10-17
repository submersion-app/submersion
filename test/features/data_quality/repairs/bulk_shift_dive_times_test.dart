import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  test('shifts entry, exit and legacy dateTime by the offset', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await repo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: entry,
        entryTime: entry,
        exitTime: entry.add(const Duration(minutes: 40)),
      ),
    );
    await repo.bulkShiftDiveTimes(['d1'], const Duration(hours: -6));
    final shifted = (await repo.getDiveById('d1'))!;
    // dive_date_time shifts too (the SQL updates it unconditionally).
    expect(shifted.dateTime, entry.subtract(const Duration(hours: 6)));
    expect(shifted.entryTime, entry.subtract(const Duration(hours: 6)));
    expect(
      shifted.exitTime,
      entry.add(const Duration(minutes: 40)).subtract(const Duration(hours: 6)),
    );
  });

  test('null exitTime stays null', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await repo.createDive(
      domain.Dive(id: 'd2', dateTime: entry, entryTime: entry),
    );
    await repo.bulkShiftDiveTimes(['d2'], const Duration(hours: 2));
    final shifted = (await repo.getDiveById('d2'))!;
    expect(shifted.exitTime, isNull);
    expect(shifted.entryTime, entry.add(const Duration(hours: 2)));
  });

  test('snapshot + restore round-trips exactly', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await repo.createDive(
      domain.Dive(id: 'd3', dateTime: entry, entryTime: entry),
    );
    final snapshot = await repo.getDiveTimesSnapshot(['d3']);
    await repo.bulkShiftDiveTimes(['d3'], const Duration(hours: 5));
    await repo.restoreDiveTimes(snapshot);
    final restored = (await repo.getDiveById('d3'))!;
    expect(restored.entryTime, entry);
  });

  test('shiftDiveTimes shifts every time column and tells sync', () async {
    final entry = DateTime.utc(2026, 3, 15, 14, 30);
    await repo.createDive(
      domain.Dive(
        id: 'd4',
        dateTime: entry,
        entryTime: entry,
        exitTime: entry.add(const Duration(minutes: 42)),
      ),
    );
    var notified = 0;
    final subscription = SyncEventBus.changes.listen((_) => notified++);
    addTearDown(subscription.cancel);

    await repo.shiftDiveTimes(['d4'], const Duration(hours: -5));
    await pumpEventQueue();

    final shifted = (await repo.getDiveById('d4'))!;
    final wallClock = DateTime.utc(2026, 3, 15, 9, 30);
    expect(shifted.dateTime, wallClock);
    expect(shifted.entryTime, wallClock);
    expect(shifted.exitTime, wallClock.add(const Duration(minutes: 42)));
    expect(notified, 1);
  });

  test('shiftDiveTimes with nothing to move stays quiet', () async {
    var notified = 0;
    final subscription = SyncEventBus.changes.listen((_) => notified++);
    addTearDown(subscription.cancel);

    await repo.shiftDiveTimes(const [], const Duration(hours: 1));
    await repo.shiftDiveTimes(['missing'], Duration.zero);
    await pumpEventQueue();

    expect(notified, 0);
  });

  test('zero offset and empty ids are no-ops', () async {
    await repo.bulkShiftDiveTimes(const [], const Duration(hours: 1));
    await repo.bulkShiftDiveTimes(['missing'], Duration.zero);
    // No throw is the assertion.
  });
}
