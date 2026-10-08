import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';

import '../../../helpers/test_database.dart';

/// Sync of the role junctions `dive_diver_roles` and `dive_buddy_roles`
/// (v272, issue #1221).
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  Map<String, dynamic> diverRow(String id, {String role = 'diveMaster'}) => {
    'id': id,
    'diveId': 'd1',
    'roleId': role,
    'createdAt': 1,
    'hlc': null,
  };

  Map<String, dynamic> buddyRow(String id, {String role = 'diveGuide'}) => {
    'id': id,
    'diveId': 'd1',
    'buddyId': 'b1',
    'roleId': role,
    'createdAt': 1,
    'hlc': null,
  };

  test('both junctions export under their entity keys', () async {
    await db.customStatement(
      'INSERT INTO dive_diver_roles (id, dive_id, role_id, created_at) '
      "VALUES ('r1', 'd1', 'diveMaster', 1)",
    );
    await db.customStatement(
      'INSERT INTO dive_buddy_roles '
      '(id, dive_id, buddy_id, role_id, created_at) '
      "VALUES ('x1', 'd1', 'b1', 'diveGuide', 1)",
    );

    final changeset = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    expect(changeset.data.diveDiverRoles.map((r) => r['id']), ['r1']);
    expect(changeset.data.diveBuddyRoles.map((r) => r['id']), ['x1']);
  });

  group('diveDiverRoles', () {
    test('a row round-trips through fetch, delete and upsert', () async {
      await serializer.upsertRecord('diveDiverRoles', diverRow('r1'));
      final json = await serializer.fetchRecord('diveDiverRoles', 'r1');
      expect(json?['roleId'], 'diveMaster');

      await serializer.deleteRecord('diveDiverRoles', 'r1');
      expect(await serializer.fetchRecord('diveDiverRoles', 'r1'), isNull);
    });

    test('a peer copy under a lower id replaces the local row', () async {
      await serializer.upsertRecord('diveDiverRoles', diverRow('r-b'));
      await serializer.upsertRecord('diveDiverRoles', diverRow('r-a'));
      final rows = await db.select(db.diveDiverRoles).get();
      expect(rows.map((r) => r.id), ['r-a']);
    });

    test('a peer copy under a higher id is skipped', () async {
      await serializer.upsertRecord('diveDiverRoles', diverRow('r-a'));
      await serializer.upsertRecord('diveDiverRoles', diverRow('r-b'));
      final rows = await db.select(db.diveDiverRoles).get();
      expect(rows.map((r) => r.id), ['r-a']);
    });

    test('a batch with two rows for one key keeps the lower id', () async {
      await serializer.upsertRecords('diveDiverRoles', [
        diverRow('r-b'),
        diverRow('r-a'),
      ]);
      final rows = await db.select(db.diveDiverRoles).get();
      expect(rows.map((r) => r.id), ['r-a']);
    });
  });

  group('diveBuddyRoles', () {
    test('a row round-trips through fetch, delete and upsert', () async {
      await serializer.upsertRecord('diveBuddyRoles', buddyRow('x1'));
      final json = await serializer.fetchRecord('diveBuddyRoles', 'x1');
      expect(json?['buddyId'], 'b1');

      await serializer.deleteRecord('diveBuddyRoles', 'x1');
      expect(await serializer.fetchRecord('diveBuddyRoles', 'x1'), isNull);
    });

    test('a peer copy under a lower id replaces the local row', () async {
      await serializer.upsertRecord('diveBuddyRoles', buddyRow('x-b'));
      await serializer.upsertRecord('diveBuddyRoles', buddyRow('x-a'));
      final rows = await db.select(db.diveBuddyRoles).get();
      expect(rows.map((r) => r.id), ['x-a']);
    });

    test('a peer copy under a higher id is skipped', () async {
      await serializer.upsertRecord('diveBuddyRoles', buddyRow('x-a'));
      await serializer.upsertRecord('diveBuddyRoles', buddyRow('x-b'));
      final rows = await db.select(db.diveBuddyRoles).get();
      expect(rows.map((r) => r.id), ['x-a']);
    });

    test('a batch with two rows for one key keeps the lower id', () async {
      await serializer.upsertRecords('diveBuddyRoles', [
        buddyRow('x-b'),
        buddyRow('x-a'),
        buddyRow('x-c', role: 'instructor'),
      ]);
      final rows = await db.select(db.diveBuddyRoles).get();
      expect(rows.map((r) => r.id).toSet(), {'x-a', 'x-c'});
    });
  });

  test('a secondary role reaches an incremental changeset without a dive '
      'change', () async {
    final roles = DiveRoleLinkRepository();
    await roles.writeDiverRoles('d1', ['diveGuide']);
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    final watermark = dive.hlc!;

    // Dive Master sorts after Dive Guide, so the primary (and the dives row)
    // is untouched: only a junction row is written.
    await roles.writeDiverRoles('d1', ['diveGuide', 'diveMaster']);
    final after = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(after.hlc, watermark, reason: 'the dive row was not restamped');

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(changeset.data.dives.map((r) => r['id']), isNot(contains('d1')));
    expect(
      changeset.data.diveDiverRoles.map((r) => r['roleId']),
      contains('diveMaster'),
    );
  });
}
