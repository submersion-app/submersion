import 'package:drift/drift.dart' show TableUpdateQuery, Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// What an equipment set carries besides gear (issue #4525) through the sync
/// serializer: the three junction tables export, apply, fetch and delete by
/// their own row id, and are wired as parent-gated children of the set.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  const entities = <String, (String ref, String refValue)>{
    'equipmentSetIncludes': ('includedSetId', 'inner'),
    'equipmentSetWeightPresets': ('presetId', 'p1'),
    'equipmentSetCylinderConfigs': ('configId', 'c1'),
  };

  const tableNames = {
    'equipmentSetIncludes': 'equipment_set_includes',
    'equipmentSetWeightPresets': 'equipment_set_weight_presets',
    'equipmentSetCylinderConfigs': 'equipment_set_cylinder_configs',
  };

  Map<String, dynamic> row(String type, {String id = 'r1', int sortOrder = 0}) {
    final (ref, refValue) = entities[type]!;
    return {
      'id': id,
      'setId': 'outer',
      ref: refValue,
      'sortOrder': sortOrder,
      'createdAt': 1,
      'hlc': null,
    };
  }

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    const t = 1700000000000;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'D',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final id in ['outer', 'inner']) {
      await db
          .into(db.equipmentSets)
          .insert(
            EquipmentSetsCompanion.insert(
              id: id,
              name: id,
              diverId: const Value('d1'),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.weightPresets)
        .insert(
          WeightPresetsCompanion.insert(
            id: 'p1',
            displayName: 'Belt',
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.cylinderConfigs)
        .insert(
          CylinderConfigsCompanion.insert(
            id: 'c1',
            name: 'AL80',
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  for (final type in entities.keys) {
    test('$type: a row applies, fetches and deletes by its id', () async {
      await serializer.upsertRecord(type, row(type, sortOrder: 2));
      final stored = await serializer.fetchRecord(type, 'r1');
      expect(stored, isNotNull);
      expect(stored!['setId'], 'outer');
      expect(stored['sortOrder'], 2);
      expect(await serializer.recordIdsFor(type), {'r1'});

      final many = await serializer.fetchRecords(type, ['r1', 'missing']);
      expect(many.keys, ['r1']);

      await serializer.deleteRecord(type, 'r1');
      expect(await serializer.fetchRecord(type, 'r1'), isNull);
    });

    test('$type: a batch applies and a full export returns it', () async {
      await serializer.upsertRecords(type, [row(type)]);
      final data = (await serializer.exportData(
        deviceId: 'peer',
        deletions: const [],
      )).data.toJson();
      final exported = (data[type] as List).cast<Map<String, dynamic>>();
      expect(exported.map((r) => r['id']), ['r1']);
    });

    // Two devices that each add the same target to the same set mint their
    // own row id for one pair; the pair is unique, so an upsert keyed on the
    // id alone fails the whole batch. Lowest id wins on both sides.
    test('$type: a peer row for a pair held under a higher id replaces '
        'it', () async {
      await serializer.upsertRecord(type, row(type, id: 'r9'));
      await serializer.upsertRecord(type, row(type, id: 'r1', sortOrder: 3));
      expect(await serializer.recordIdsFor(type), {'r1'});
      expect((await serializer.fetchRecord(type, 'r1'))!['sortOrder'], 3);
    });

    test('$type: a peer row for a pair held under a lower id is '
        'skipped', () async {
      await serializer.upsertRecord(type, row(type, id: 'r1', sortOrder: 3));
      await serializer.upsertRecord(type, row(type, id: 'r9'));
      expect(await serializer.recordIdsFor(type), {'r1'});
      expect((await serializer.fetchRecord(type, 'r1'))!['sortOrder'], 3);
    });

    test('$type: a batch carrying one pair twice, over a local copy, '
        'settles on the lowest id', () async {
      await serializer.upsertRecord(type, row(type, id: 'r5'));
      await serializer.upsertRecords(type, [
        row(type, id: 'r7'),
        row(type, id: 'r2', sortOrder: 4),
      ]);
      expect(await serializer.recordIdsFor(type), {'r2'});
      expect((await serializer.fetchRecord(type, 'r2'))!['sortOrder'], 4);
    });

    test('$type: a batch whose pair is held under a lower id changes '
        'nothing', () async {
      await serializer.upsertRecord(type, row(type, id: 'r1', sortOrder: 3));
      await serializer.upsertRecords(type, [row(type, id: 'r9')]);
      expect(await serializer.recordIdsFor(type), {'r1'});
    });

    test('$type: the same id again updates its order', () async {
      await serializer.upsertRecord(type, row(type));
      await serializer.upsertRecord(type, row(type, sortOrder: 5));
      await serializer.upsertRecords(type, [row(type, sortOrder: 6)]);
      expect((await serializer.fetchRecord(type, 'r1'))!['sortOrder'], 6);
    });

    // The set pages refresh from table updates, which a raw statement
    // does not send by itself.
    test('$type: applying a row tells the table\'s watchers', () async {
      final table = db.allTables.firstWhere(
        (t) => t.actualTableName == tableNames[type],
      );
      final ticked = db
          .tableUpdates(TableUpdateQuery.onTable(table))
          .first
          .timeout(const Duration(seconds: 2));
      await serializer.upsertRecord(type, row(type));
      await ticked;
    });

    test('$type: is a parent-gated child with no updatedAt', () {
      expect(SyncDataSerializer.parentGatedChildEntities, contains(type));
      expect(SyncService.entityHasUpdatedAt[type], isFalse);
      final refs = SyncService.parentRefs[type]!;
      expect(refs.map((r) => r.field), ['setId', entities[type]!.$1]);
      expect(refs.every((r) => !r.nullable), isTrue);
    });
  }

  test('an incremental export re-sends the lists of a set whose clock moved, '
      'and nothing for one that did not', () async {
    for (final type in entities.keys) {
      await serializer.upsertRecord(type, row(type));
    }
    await (db.update(db.equipmentSets)..where((s) => s.id.equals('outer')))
        .write(const EquipmentSetsCompanion(hlc: Value('0000000000000002')));

    final moved = (await serializer.exportChangeset(
      deviceId: 'peer',
      hlcWatermark: '0000000000000001',
      deletions: const [],
    )).data.toJson();
    for (final type in entities.keys) {
      expect((moved[type] as List), hasLength(1), reason: type);
    }

    final still = (await serializer.exportChangeset(
      deviceId: 'peer',
      hlcWatermark: '0000000000000003',
      deletions: const [],
    )).data.toJson();
    for (final type in entities.keys) {
      expect((still[type] as List), isEmpty, reason: type);
    }
  });
}
