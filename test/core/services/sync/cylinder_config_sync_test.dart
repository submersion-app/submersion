import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedUnit(String id) => serializer.upsertRecord('equipment', {
    'id': id,
    'name': 'JJ-CCR',
    'type': 'rebreather',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1000,
    'updatedAt': 1000,
  });

  Future<void> seedConfig(String id, {String? equipmentId}) =>
      serializer.upsertRecord('cylinderConfigs', {
        'id': id,
        'equipmentId': equipmentId,
        'name': 'JJ trimix',
        'description': '',
        'sortOrder': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  Future<void> seedItem(
    String id,
    String configId, {
    String role = 'diluent',
    double o2 = 18,
    double he = 45,
  }) => serializer.upsertRecord('cylinderConfigItems', {
    'id': id,
    'configId': configId,
    'sortOrder': 0,
    'tankRole': role,
    'o2Percent': o2,
    'hePercent': he,
    'createdAt': 1000,
    'updatedAt': 1000,
  });

  test('a config and its items export intact', () async {
    await seedUnit('rb-1');
    await seedConfig('c1', equipmentId: 'rb-1');
    await seedItem('i1', 'c1');

    final payload = await serializer.exportData(
      deviceId: 'test-device',
      deletions: const [],
    );

    final configs = payload.data.cylinderConfigs;
    expect(configs.map((c) => c['id']), contains('c1'));
    expect(configs.single['equipmentId'], 'rb-1');

    final items = payload.data.cylinderConfigItems;
    expect(items.map((i) => i['id']), contains('i1'));
    expect(items.single['o2Percent'], 18);
    expect(items.single['hePercent'], 45);
    expect(items.single['tankRole'], 'diluent');
  });

  test('a generic gas plan with no owning unit round-trips', () async {
    await seedConfig('c1');
    await seedItem('i1', 'c1', role: 'backGas', o2: 21, he: 0);

    final payload = await serializer.exportData(
      deviceId: 'test-device',
      deletions: const [],
    );

    expect(payload.data.cylinderConfigs.single['equipmentId'], isNull);
  });

  test('the exported payload survives a JSON round-trip', () async {
    await seedConfig('c1');
    await seedItem('i1', 'c1');

    final payload = await serializer.exportData(
      deviceId: 'test-device',
      deletions: const [],
    );
    final revived = SyncData.fromJson(payload.data.toJson());

    expect(revived.cylinderConfigs.map((c) => c['id']), contains('c1'));
    expect(revived.cylinderConfigItems.map((i) => i['id']), contains('i1'));
  });

  test('parentRefs guards every FK to a deletable parent', () {
    // The merge applies remote records in a deferred-FK transaction. An
    // unguarded FK to a locally-deleted parent dangles and fails the whole
    // sync at COMMIT (SqliteException 787). Merge ORDER is enforced by the
    // inline list in SyncService plus the no-silent-drift check in
    // sync_parent_refs_completeness_test; this pins the guards themselves.
    final configRefs = SyncService.parentRefs['cylinderConfigs']!;
    expect(
      configRefs.map((r) => '${r.field}->${r.parent}:${r.nullable}'),
      containsAll([
        'diverId->divers:true',
        // Nullable by design: deleting a rebreather demotes its configs to
        // generic gas plans rather than destroying them, so the reference is
        // cleared instead of the row being skipped.
        'equipmentId->equipment:true',
      ]),
    );

    final itemRefs = SyncService.parentRefs['cylinderConfigItems']!;
    expect(
      itemRefs.map((r) => '${r.field}->${r.parent}:${r.nullable}'),
      contains('configId->cylinderConfigs:false'),
    );
  });

  test('both entities declare updatedAt so HLC comparison works', () {
    expect(SyncService.entityHasUpdatedAt['cylinderConfigs'], isTrue);
    expect(SyncService.entityHasUpdatedAt['cylinderConfigItems'], isTrue);
  });

  test('deleting a config through the serializer removes it', () async {
    await seedConfig('c1');
    await seedItem('i1', 'c1');

    await serializer.deleteRecord('cylinderConfigItems', 'i1');
    await serializer.deleteRecord('cylinderConfigs', 'c1');

    final payload = await serializer.exportData(
      deviceId: 'test-device',
      deletions: const [],
    );
    expect(payload.data.cylinderConfigs, isEmpty);
    expect(payload.data.cylinderConfigItems, isEmpty);
  });

  test('a single config and item are fetchable by id', () async {
    // The per-record fetch is what the conflict resolver reads to compare a
    // local row against an incoming one, so a missing case here silently
    // resolves every conflict in the remote's favour.
    await seedUnit('rb-1');
    await seedConfig('c1', equipmentId: 'rb-1');
    await seedItem('i1', 'c1');

    final config = await serializer.fetchRecord('cylinderConfigs', 'c1');
    expect(config, isNotNull);
    expect(config!['name'], 'JJ trimix');
    expect(config['equipmentId'], 'rb-1');

    final item = await serializer.fetchRecord('cylinderConfigItems', 'i1');
    expect(item, isNotNull);
    expect(item!['configId'], 'c1');
    expect(item['tankRole'], 'diluent');

    expect(await serializer.fetchRecord('cylinderConfigs', 'missing'), isNull);
  });

  test('configs and items round-trip through the batch paths', () async {
    // The streaming/base sync paths use the batch variants (fetchRecords /
    // upsertRecords), distinct from the single-record CRUD above.
    await serializer.upsertRecords('cylinderConfigs', [
      {
        'id': 'c1',
        'name': 'JJ trimix',
        'description': '',
        'sortOrder': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
      {
        'id': 'c2',
        'name': 'Doubles + 50',
        'description': '',
        'sortOrder': 1,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
    ]);

    await serializer.upsertRecords('cylinderConfigItems', [
      {
        'id': 'i1',
        'configId': 'c1',
        'sortOrder': 0,
        'tankRole': 'diluent',
        'o2Percent': 18.0,
        'hePercent': 45.0,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
      {
        'id': 'i2',
        'configId': 'c1',
        'sortOrder': 1,
        'tankRole': 'bailout',
        'o2Percent': 21.0,
        'hePercent': 0.0,
        'createdAt': 1000,
        'updatedAt': 1000,
      },
    ]);

    final configs = await serializer.fetchRecords('cylinderConfigs', [
      'c1',
      'c2',
    ]);
    expect(configs.keys, containsAll(['c1', 'c2']));
    expect(configs['c2']!['name'], 'Doubles + 50');

    final items = await serializer.fetchRecords('cylinderConfigItems', [
      'i1',
      'i2',
    ]);
    expect(items.keys, containsAll(['i1', 'i2']));
    expect(items['i2']!['tankRole'], 'bailout');
  });

  test(
    'an incremental changeset carries only rows past the watermark',
    () async {
      // Rows arriving from a peer carry an hlc; the watermark filter is what
      // keeps an incremental changeset from re-sending the whole table.
      const oldHlc = '2026-07-01T00:00:00.000Z-0000-peer';
      const newHlc = '2026-08-01T00:00:00.000Z-0000-peer';

      await serializer.upsertRecord('cylinderConfigs', {
        'id': 'old',
        'name': 'Unchanged',
        'description': '',
        'sortOrder': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
        'hlc': oldHlc,
      });
      await serializer.upsertRecord('cylinderConfigs', {
        'id': 'new',
        'name': 'Edited',
        'description': '',
        'sortOrder': 0,
        'createdAt': 1000,
        'updatedAt': 2000,
        'hlc': newHlc,
      });
      await serializer.upsertRecord('cylinderConfigItems', {
        'id': 'i-old',
        'configId': 'old',
        'sortOrder': 0,
        'tankRole': 'diluent',
        'o2Percent': 18.0,
        'hePercent': 45.0,
        'createdAt': 1000,
        'updatedAt': 1000,
        'hlc': oldHlc,
      });
      await serializer.upsertRecord('cylinderConfigItems', {
        'id': 'i-new',
        'configId': 'new',
        'sortOrder': 0,
        'tankRole': 'bailout',
        'o2Percent': 21.0,
        'hePercent': 0.0,
        'createdAt': 1000,
        'updatedAt': 2000,
        'hlc': newHlc,
      });

      final changeset = await serializer.exportChangeset(
        deviceId: 'test-device',
        hlcWatermark: oldHlc,
        deletions: const [],
      );

      final configIds = changeset.data.cylinderConfigs
          .map((c) => c['id'])
          .toSet();
      expect(configIds, contains('new'));
      expect(
        configIds,
        isNot(contains('old')),
        reason: 'a config at the watermark must not be re-sent',
      );

      final itemIds = changeset.data.cylinderConfigItems
          .map((i) => i['id'])
          .toSet();
      expect(itemIds, contains('i-new'));
      expect(itemIds, isNot(contains('i-old')));
    },
  );
}
