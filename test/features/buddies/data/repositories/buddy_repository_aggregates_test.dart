import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

/// Inserts a dive whose `dive_date_time` is [at], a wall clock flagged UTC,
/// the way the app persists it.
Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required DateTime at,
}) async {
  assert(at.isUtc, 'dive_date_time is stored as a wall clock flagged UTC');
  final ms = at.millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(ms),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _link(
  db.AppDatabase database, {
  required String diveId,
  required String buddyId,
  String role = DiveRole.buddyId,
}) async {
  await database
      .into(database.diveBuddies)
      .insert(
        db.DiveBuddiesCompanion(
          id: Value('$diveId-$buddyId'),
          diveId: Value(diveId),
          buddyId: Value(buddyId),
          role: Value(role),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
}

void main() {
  late BuddyRepository repository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
    database = DatabaseService.instance.database;
    final now = DateTime(2026, 1, 1);
    await repository.createBuddy(
      Buddy(id: 'jane', name: 'Jane', createdAt: now, updatedAt: now),
    );
    await repository.createBuddy(
      Buddy(id: 'ken', name: 'Ken', createdAt: now, updatedAt: now),
    );
    await _insertDive(database, id: 'd1', at: DateTime.utc(2024, 1, 10));
    // Late in the evening, so reading it back with the device's UTC offset
    // applied would move it to another day for most of the world.
    await _insertDive(database, id: 'd2', at: DateTime.utc(2024, 3, 5, 23, 30));
    await _insertDive(database, id: 'd3', at: DateTime.utc(2024, 2, 1, 0, 30));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<BuddyWithDiveCount> load(String id) async {
    final all = await repository.getAllBuddiesWithDiveCount();
    return all.singleWhere((b) => b.buddy.id == id);
  }

  test('lastDiveAt is the most recent linked dive', () async {
    await _link(database, diveId: 'd1', buddyId: 'jane');
    await _link(database, diveId: 'd2', buddyId: 'jane');
    await _link(database, diveId: 'd3', buddyId: 'jane');

    final jane = await load('jane');

    expect(jane.diveCount, 3);
    expect(jane.lastDiveAt, DateTime.utc(2024, 3, 5, 23, 30));
  });

  // Issue #2805: dive_date_time is a wall clock flagged UTC. Decoding it as a
  // local DateTime shifts the displayed date by the device's UTC offset, which
  // CI (running in UTC) cannot see, so these assert the flag as well as the
  // wall-clock fields.
  test('lastDiveAt keeps the dive wall clock, flagged UTC (#2805)', () async {
    await _link(database, diveId: 'd2', buddyId: 'jane');

    final lastDiveAt = (await load('jane')).lastDiveAt!;

    expect(lastDiveAt.isUtc, isTrue);
    expect(
      [lastDiveAt.year, lastDiveAt.month, lastDiveAt.day, lastDiveAt.hour],
      [2024, 3, 5, 23],
    );
  });

  test(
    'getBuddyStats first and last dive keep the wall clock (#2805)',
    () async {
      await _link(database, diveId: 'd1', buddyId: 'jane');
      await _link(database, diveId: 'd2', buddyId: 'jane');
      await _link(database, diveId: 'd3', buddyId: 'jane');

      final stats = await repository.getBuddyStats('jane');

      expect(stats.firstDive, DateTime.utc(2024, 1, 10));
      expect(stats.lastDive, DateTime.utc(2024, 3, 5, 23, 30));
      expect(stats.firstDive!.isUtc, isTrue);
      expect(stats.lastDive!.isUtc, isTrue);
    },
  );

  test('a buddy with no dives has null aggregates and zero count', () async {
    final ken = await load('ken');

    expect(ken.diveCount, 0);
    expect(ken.lastDiveAt, isNull);
    expect(ken.usualRoleId, isNull);
  });

  test('usualRoleId is the most frequent role', () async {
    await _link(
      database,
      diveId: 'd1',
      buddyId: 'jane',
      role: DiveRole.instructorId,
    );
    await _link(
      database,
      diveId: 'd2',
      buddyId: 'jane',
      role: DiveRole.instructorId,
    );
    await _link(database, diveId: 'd3', buddyId: 'jane');

    expect((await load('jane')).usualRoleId, DiveRole.instructorId);
  });

  test('usualRoleId breaks ties on role id ascending', () async {
    await _link(
      database,
      diveId: 'd1',
      buddyId: 'ken',
      role: DiveRole.instructorId,
    );
    await _link(database, diveId: 'd2', buddyId: 'ken');

    expect((await load('ken')).usualRoleId, DiveRole.buddyId);
  });
}
