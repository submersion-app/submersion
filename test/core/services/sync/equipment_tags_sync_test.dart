import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync of equipment tag links (issue #1942): the `equipmentTags` entity,
/// the equipment twin of `siteTags`.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('t1', 'Travel kit', 1, 1, 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> link(String id, String equipmentId, String tagId) =>
      db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('$id', '$equipmentId', '$tagId', 1)",
      );

  Future<int> pending(String entityType) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_records '
          "WHERE entity_type = '$entityType'",
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<Tag> tagRow(String id) =>
      (db.select(db.tags)..where((t) => t.id.equals(id))).getSingle();

  test('a link round-trips through fetch, delete and upsert', () async {
    await link('et1', 'e1', 't1');
    final json = await serializer.fetchRecord('equipmentTags', 'et1');
    expect(json, isNotNull);
    expect(await serializer.recordIdsFor('equipmentTags'), contains('et1'));
    expect(
      (await serializer.fetchRecords('equipmentTags', ['et1', 'x'])).keys,
      ['et1'],
    );

    await serializer.deleteRecord('equipmentTags', 'et1');
    expect(await serializer.fetchRecord('equipmentTags', 'et1'), isNull);
    await serializer.upsertRecord('equipmentTags', json!);

    final rows = await db.select(db.equipmentTags).get();
    expect(rows.single.tagId, 't1');
  });

  test('links round-trip between two databases', () async {
    await link('et1', 'e1', 't1');
    final payload = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    final decoded = SyncData.fromJson(
      jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.equipmentTags.map((r) => r['id']), ['et1']);

    // The serializer reads DatabaseService.instance.database, so point the
    // service at the receiving database for the apply. The tearDown closes
    // that one; this closes the sender.
    addTearDown(db.close);
    final receiver = AppDatabase(NativeDatabase.memory());
    DatabaseService.instance.resetForTesting();
    DatabaseService.instance.setTestDatabase(receiver);
    final applier = SyncDataSerializer();
    await applier.applyInDeferredFkTransaction(() async {
      await applier.upsertRecords('equipment', decoded.equipment);
      await applier.upsertRecords('tags', decoded.tags);
      await applier.upsertRecords('equipmentTags', decoded.equipmentTags);
    });

    final links = await receiver.select(receiver.equipmentTags).get();
    expect(links.map((l) => (l.id, l.equipmentId, l.tagId)), [
      ('et1', 'e1', 't1'),
    ]);
  });

  test('a duplicate pair from a peer applies without throwing', () async {
    await link('local', 'e1', 't1');

    await serializer.upsertRecords('equipmentTags', [
      {
        'id': 'peer',
        'equipmentId': 'e1',
        'tagId': 't1',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    await serializer.upsertRecord('equipmentTags', {
      'id': 'peer2',
      'equipmentId': 'e1',
      'tagId': 't1',
      'createdAt': 3,
      'hlc': null,
    });

    final rows = await db.select(db.equipmentTags).get();
    expect(rows.map((r) => r.id), ['local']);
  });

  test("applying a peer's link never marks the item pending", () async {
    await serializer.upsertRecord('equipmentTags', {
      'id': 'et1',
      'equipmentId': 'e1',
      'tagId': 't1',
      'createdAt': 2,
      'hlc': null,
    });

    expect(await pending('equipment'), 0);
    final item = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('e1'))).getSingle();
    expect(item.hlc, isNull);
    expect(item.updatedAt, 1);
  });

  test('a pending link travels without its item', () async {
    const itemHlc = '2026-08-01T00:00:00.000Z-0000-peer';
    await db.customStatement(
      "UPDATE equipment SET hlc = '$itemHlc' WHERE id = 'e1'",
    );
    await EquipmentTagRepository().addTags(['e1'], ['t1']);

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: itemHlc,
      deletions: const [],
    );

    expect(
      changeset.data.equipment,
      isEmpty,
      reason: 'the item did not change',
    );
    expect(changeset.data.equipmentTags.map((r) => r['tagId']), ['t1']);
    expect(await pending('equipment'), 0);
  });

  test("an incremental changeset carries only changed items' links", () async {
    const oldHlc = '2026-07-01T00:00:00.000Z-0000-peer';
    const newHlc = '2026-08-01T00:00:00.000Z-0000-peer';
    await db.customStatement(
      "UPDATE equipment SET hlc = '$oldHlc' WHERE id = 'e1'",
    );
    await db.customStatement(
      "UPDATE equipment SET hlc = '$newHlc' WHERE id = 'e2'",
    );
    await link('tag-e1', 'e1', 't1');
    await link('tag-e2', 'e2', 't1');

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: oldHlc,
      deletions: const [],
    );

    expect(changeset.data.equipmentTags.map((r) => r['id']), ['tag-e2']);
  });

  test('links follow a tag folded into a same-name rival', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('aaa', 'Rental', 1, 1, 1, 0, 0)",
    );
    // A peer's tag of the same name folds into the local survivor 'aaa'.
    await serializer.upsertRecord('tags', {
      'id': 'zzz',
      'diverId': null,
      'name': 'rental',
      'color': null,
      'createdAt': 2,
      'updatedAt': 2,
      'hlc': null,
      'appliesToDives': false,
      'appliesToSites': false,
      'appliesToEquipment': true,
    });
    await serializer.upsertRecord('equipmentTags', {
      'id': 'et1',
      'equipmentId': 'e1',
      'tagId': 'zzz',
      'createdAt': 3,
      'hlc': null,
    });

    final links = await db.select(db.equipmentTags).get();
    expect(links.single.tagId, 'aaa');
    final tag = await tagRow('aaa');
    expect(
      tag.appliesToEquipment,
      isTrue,
      reason: 'the fold keeps every scope',
    );
    expect(tag.appliesToDives, isTrue);
  });

  test('a local link on a folded tag is repointed to the survivor', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('zzz', 'Avoid', 1, 1, 0, 0, 1)",
    );
    await link('et1', 'e1', 'zzz');
    await SyncRepository().clearAllSyncRecords();

    // A peer's same-name tag with a lower id wins the fold. The fold repoints
    // the link before the survivor row is written, so this runs inside the
    // deferred-FK transaction every real merge uses.
    await serializer.applyInDeferredFkTransaction(
      () => serializer.upsertRecord('tags', {
        'id': 'aaa',
        'diverId': null,
        'name': 'avoid',
        'color': null,
        'createdAt': 2,
        'updatedAt': 2,
        'hlc': null,
        'appliesToDives': true,
        'appliesToSites': false,
        'appliesToEquipment': false,
      }),
    );

    final links = await db.select(db.equipmentTags).get();
    expect(links.map((l) => (l.id, l.tagId)), [('et1', 'aaa')]);
    expect((await tagRow('aaa')).appliesToEquipment, isTrue);
    expect(await pending('equipmentTags'), 1, reason: 'the moved link');
    expect(await pending('equipment'), 0);
  });

  test('a folded tag drops its link on an item the survivor tags', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('zzz', 'Avoid', 1, 1, 0, 0, 1)",
    );
    await link('local', 'e1', 'zzz');
    await serializer.applyInDeferredFkTransaction(() async {
      // The peer's link to its own tag lands first (FKs are deferred), so
      // when the tag folds, e1 already carries the survivor.
      await link('peer', 'e1', 'aaa');
      await serializer.upsertRecord('tags', {
        'id': 'aaa',
        'diverId': null,
        'name': 'avoid',
        'color': null,
        'createdAt': 2,
        'updatedAt': 2,
        'hlc': null,
        'appliesToDives': false,
        'appliesToSites': false,
        'appliesToEquipment': true,
      });
    });

    final links = await db.select(db.equipmentTags).get();
    expect(links.map((r) => (r.id, r.tagId)), [('peer', 'aaa')]);
  });

  test(
    'a new tag from an older peer applies with the equipment scope off',
    () async {
      // Passes as soon as the column exists: _withSchemaDefaults (#858) fills
      // the omitted key with the column default. Pinned for the new column.
      await serializer.upsertRecord('tags', {
        'id': 't9',
        'diverId': null,
        'name': 'Night',
        'color': null,
        'createdAt': 1,
        'updatedAt': 1,
        'hlc': null,
        'appliesToDives': true,
        'appliesToSites': false,
      });

      final tag = await tagRow('t9');
      expect(tag.appliesToEquipment, isFalse);
      expect(tag.appliesToDives, isTrue);
    },
  );

  group('older peers', () {
    late FakeCloudStorageProvider cloud;

    setUp(() => cloud = FakeCloudStorageProvider());

    SyncPayload payloadOf(SyncData data) {
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: data,
        deletions: const {},
      );
    }

    test(
      'a tag row with no applies_to_equipment key keeps the local scope',
      () async {
        await db.customStatement(
          "UPDATE tags SET hlc = '2026-01-01T00:00:00.000Z-0000-deva' "
          "WHERE id = 't1'",
        );

        // The peer renamed the tag on a v218 build: its row carries the dive
        // and site flags, no equipment flag, and a newer clock, so it wins.
        final olderPeerRow = <String, dynamic>{
          'id': 't1',
          'diverId': null,
          'name': 'Travel kit (carry-on)',
          'color': null,
          'createdAt': 1,
          'updatedAt': 9,
          'hlc': '2026-09-01T00:00:00.000Z-0000-devb',
          'appliesToDives': false,
          'appliesToSites': false,
        };
        await seedPeerBaseFromPayload(
          cloud,
          'peer-dev',
          payloadOf(SyncData(tags: [olderPeerRow])),
        );

        final result = await SyncService(
          syncRepository: SyncRepository(),
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
        ).performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final tag = await tagRow('t1');
        expect(tag.name, 'Travel kit (carry-on)');
        expect(tag.appliesToEquipment, isTrue);
      },
    );
  });
}
