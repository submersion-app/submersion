import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';
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

  group('updating a downloaded dive from the same computer', () {
    Future<String> download(DiveComputerRepository repo) => repo.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0),
        ProfilePointData(timestamp: 60, depth: 10),
      ],
      durationSeconds: 120,
      maxDepth: 10,
      isPrimary: true,
      events: const [EventData(timestamp: 30, type: 'safetystop')],
    );

    setUp(() async {
      await db.customStatement(
        'INSERT INTO dive_computers (id, name, created_at, updated_at) '
        "VALUES ('comp-1', 'comp-1', 1, 1)",
      );
    });

    test('downloaded events carry a clock', () async {
      final diveId = await download(DiveComputerRepository());

      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(events, isNotEmpty);
      expect(events.map((e) => e.hlc), everyElement(isNotNull));
    });

    test('replaces the events under one scope, and the fresh events are '
        'newer than it', () async {
      final repo = DiveComputerRepository();
      final diveId = await download(repo);

      await repo.clearSourceAndProfiles(diveId: diveId, computerId: 'comp-1');
      expect(await download(repo), diveId, reason: 'matched back to the dive');

      final scope = (await db.select(db.deletionLog).get()).singleWhere(
        (t) => t.entityType.startsWith('diveProfileEvents'),
      );
      expect(scope.entityType, EventScopeTombstone.entityType);
      expect(scope.recordId, diveId);
      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(events, isNotEmpty);
      for (final e in events) {
        expect(
          Hlc.parse(e.hlc!).compareTo(Hlc.parse(scope.originHlc!)),
          greaterThan(0),
          reason: 'a peer applying the scope must keep the fresh events',
        );
      }
    });
  });

  test('clearing a dive with no events writes no tombstone', () async {
    await DiveComputerRepository().clearEventsForDive('d1');
    await DiveRepository().deleteProfileEventsForDive('d1');

    expect(await eventTombstones(), isEmpty);
  });
}
