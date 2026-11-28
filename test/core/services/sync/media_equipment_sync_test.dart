import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Sync of gear linked to photos (issue #5046): the `mediaEquipment`
/// entity, a child of `media` gated on its clock like `mediaTags`.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;
  const entity = 'mediaEquipment';

  Future<void> seed(AppDatabase target) async {
    await target.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('i1', '', 'photo', 1, 1), ('i2', '', 'photo', 1, 1)",
    );
    await target.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Drysuit', 'drysuit', 1, 1)",
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await seed(db);
  });

  tearDown(tearDownTestDatabase);

  Future<void> link(String id, String mediaId, String equipmentId) =>
      db.customStatement(
        'INSERT INTO media_equipment (id, media_id, equipment_id, created_at) '
        "VALUES ('$id', '$mediaId', '$equipmentId', 1)",
      );

  Future<List<(String, String, String)>> links(AppDatabase target) async {
    final rows = await target
        .customSelect(
          'SELECT id, media_id, equipment_id FROM media_equipment ORDER BY id',
        )
        .get();
    return [
      for (final r in rows)
        (
          r.read<String>('id'),
          r.read<String>('media_id'),
          r.read<String>('equipment_id'),
        ),
    ];
  }

  List<Map<String, dynamic>> rowsOf(SyncData data) =>
      (data.toJson()[entity] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> peerLink(String id) => {
    'id': id,
    'mediaId': 'i1',
    'equipmentId': 'e1',
    'createdAt': 2,
    'hlc': null,
  };

  test('a link round-trips through fetch, delete and upsert', () async {
    await link('l1', 'i1', 'e1');
    final json = await serializer.fetchRecord(entity, 'l1');
    expect(json, isNotNull);
    expect(await serializer.recordIdsFor(entity), contains('l1'));
    expect((await serializer.fetchRecords(entity, ['l1', 'x'])).keys, ['l1']);

    await serializer.deleteRecord(entity, 'l1');
    expect(await serializer.fetchRecord(entity, 'l1'), isNull);
    await serializer.upsertRecord(entity, json!);

    expect(await links(db), [('l1', 'i1', 'e1')]);
  });

  test('links round-trip between two databases', () async {
    await link('l1', 'i1', 'e1');
    final payload = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    final decoded = SyncData.fromJson(
      jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
    );
    expect(rowsOf(decoded).map((r) => r['id']), ['l1']);

    addTearDown(db.close);
    final receiver = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    DatabaseService.instance.resetForTesting();
    DatabaseService.instance.setTestDatabase(receiver);
    final applier = SyncDataSerializer();
    await applier.applyInDeferredFkTransaction(() async {
      await applier.upsertRecords('media', decoded.media);
      await applier.upsertRecords('equipment', decoded.equipment);
      await applier.upsertRecords(entity, rowsOf(decoded));
    });

    expect(await links(receiver), [('l1', 'i1', 'e1')]);
  });

  test('a duplicate pair from a peer applies without throwing', () async {
    await link('local', 'i1', 'e1');

    await serializer.upsertRecords(entity, [peerLink('peer')]);
    await serializer.upsertRecord(entity, peerLink('peer2'));

    expect((await links(db)).map((l) => l.$1), ['local']);
  });

  test('unlink then relink copies of a pair settle on the lower id', () async {
    await link('m-local', 'i1', 'e1');

    await serializer.upsertRecord(entity, peerLink('a-peer'));
    expect((await links(db)).map((l) => l.$1), ['a-peer']);

    // The batch path reaches the same survivor.
    await serializer.upsertRecords(entity, [peerLink('0-peer')]);
    expect((await links(db)).map((l) => l.$1), ['0-peer']);
  });

  test("applying a peer's link never marks the photo pending", () async {
    await serializer.upsertRecord(entity, peerLink('l1'));

    final pending = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'media'",
        )
        .getSingle();
    expect(pending.read<int>('n'), 0);
    final row = await db
        .customSelect("SELECT hlc, updated_at FROM media WHERE id = 'i1'")
        .getSingle();
    expect(row.read<String?>('hlc'), isNull);
    expect(row.read<int>('updated_at'), 1);
  });

  test('a pending link travels without its photo', () async {
    const itemHlc = '2026-08-01T00:00:00.000Z-0000-peer';
    await db.customStatement(
      "UPDATE media SET hlc = '$itemHlc' WHERE id = 'i1'",
    );
    await link('l1', 'i1', 'e1');
    await SyncRepository().markRecordPending(
      entityType: entity,
      recordId: 'l1',
      localUpdatedAt: 5,
    );

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: itemHlc,
      deletions: const [],
    );

    expect(changeset.data.media, isEmpty, reason: 'the photo did not change');
    expect(rowsOf(changeset.data).map((r) => r['id']), ['l1']);
  });

  test("an incremental changeset carries only changed photos' links", () async {
    const oldHlc = '2026-07-01T00:00:00.000Z-0000-peer';
    const newHlc = '2026-08-01T00:00:00.000Z-0000-peer';
    await db.customStatement(
      "UPDATE media SET hlc = '$oldHlc' WHERE id = 'i1'",
    );
    await db.customStatement(
      "UPDATE media SET hlc = '$newHlc' WHERE id = 'i2'",
    );
    await link('link-i1', 'i1', 'e1');
    await link('link-i2', 'i2', 'e1');

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: oldHlc,
      deletions: const [],
    );

    expect(rowsOf(changeset.data).map((r) => r['id']), ['link-i2']);
  });
}
