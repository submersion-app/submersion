import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Clearing a dive's events writes one scope tombstone for the whole set,
/// not one per event (#1926).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
  });
  tearDown(() => tearDownTestDatabase());

  Future<void> seedEvents(int count) async {
    for (var i = 0; i < count; i++) {
      await db.customStatement(
        'INSERT INTO dive_profile_events '
        '(id, dive_id, timestamp, event_type, created_at) '
        "VALUES (?, 'd1', ?, 'bookmark', 1)",
        ['e$i', i],
      );
    }
  }

  Future<List<(String, String)>> eventTombstones() async => [
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType.startsWith('diveProfileEvents'))
        (t.entityType, t.recordId),
  ];

  test('clearEventsForDive writes one scope tombstone', () async {
    await seedEvents(3);

    await DiveComputerRepository().clearEventsForDive('d1');

    expect(await db.select(db.diveProfileEvents).get(), isEmpty);
    expect(await eventTombstones(), [(EventScopeTombstone.entityType, 'd1')]);
  });

  test('deleteProfileEventsForDive writes one scope tombstone', () async {
    await seedEvents(3);

    await DiveRepository().deleteProfileEventsForDive('d1');

    expect(await db.select(db.diveProfileEvents).get(), isEmpty);
    expect(await eventTombstones(), [(EventScopeTombstone.entityType, 'd1')]);
  });

  test('clearing a dive with no events writes no tombstone', () async {
    await DiveComputerRepository().clearEventsForDive('d1');
    await DiveRepository().deleteProfileEventsForDive('d1');

    expect(await eventTombstones(), isEmpty);
  });
}
