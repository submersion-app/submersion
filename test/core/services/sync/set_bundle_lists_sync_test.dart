import 'package:drift/drift.dart' show Value;
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
