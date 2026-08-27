import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Sync replication for the v104 weight-prediction tables:
/// `diver_weight_entries` (HLC entity) and `dive_plan_equipment`
/// (clockless composite-PK junction).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('weight prediction sync (v104)', () {
    setUp(() async {
      await setUpTestDatabase();
      final db = DatabaseService.instance.database;
      // FK parents for both entities.
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-1', 'Eric', 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO dive_plans (id, name, gf_low, gf_high, created_at, "
        "updated_at) VALUES ('p1', 'Plan', 30, 70, 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO equipment (id, name, type, created_at, updated_at) "
        "VALUES ('e1', 'BCD', 'bcd', 1000, 1000)",
      );
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    Map<String, dynamic> weightEntryRow(
      String id, {
      required String hlc,
      double weightKg = 82.0,
      double? heightCm = 180.0,
    }) => {
      'id': id,
      'diverId': 'diver-1',
      'measuredAt': 5000,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': hlc,
    };

    Map<String, dynamic> planEquipmentRow() => {
      'planId': 'p1',
      'equipmentId': 'e1',
    };

    test('export includes rows from both tables', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'diverWeightEntries',
        weightEntryRow('w1', hlc: hlcAt(1000, 'dev-a')),
      );
      await serializer.upsertRecord('divePlanEquipment', planEquipmentRow());

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );

      expect(
        payload.data.diverWeightEntries.map((r) => r['id']),
        contains('w1'),
      );
      expect(
        payload.data.divePlanEquipment.map(
          (r) => '${r['planId']}|${r['equipmentId']}',
        ),
        contains('p1|e1'),
      );

      final rehydrated = SyncData.fromJson(payload.data.toJson());
      expect(rehydrated.diverWeightEntries.map((r) => r['id']), contains('w1'));
      expect(rehydrated.divePlanEquipment, hasLength(1));
    });

    test('diverWeightEntries upsert is full-row: explicit null clears '
        'heightCm (toCompanion(false) semantics)', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'diverWeightEntries',
        weightEntryRow('w1', hlc: hlcAt(1000, 'dev-a')),
      );

      var fetched = await serializer.fetchRecord('diverWeightEntries', 'w1');
      expect(fetched!['heightCm'], 180.0);

      await serializer.upsertRecord(
        'diverWeightEntries',
        weightEntryRow('w1', hlc: hlcAt(2000, 'dev-a'), heightCm: null),
      );
      fetched = await serializer.fetchRecord('diverWeightEntries', 'w1');
      expect(
        fetched!['heightCm'],
        isNull,
        reason: 'HLC entities overwrite every column on upsert',
      );
    });

    test('divePlanEquipment per-record plumbing: fetchRecord, recordIdsFor, '
        'deleteRecord with composite ids', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('divePlanEquipment', planEquipmentRow());

      final fetched = await serializer.fetchRecord(
        'divePlanEquipment',
        'p1|e1',
      );
      expect(fetched, isNotNull);
      expect(fetched!['planId'], 'p1');

      final ids = await serializer.recordIdsFor('divePlanEquipment');
      expect(ids, contains('p1|e1'));

      await serializer.deleteRecord('divePlanEquipment', 'p1|e1');
      expect(
        await serializer.recordIdsFor('divePlanEquipment'),
        isNot(contains('p1|e1')),
      );
    });

    test('batch plumbing: upsertRecords and fetchRecords handle both '
        'entities', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecords('diverWeightEntries', [
        weightEntryRow('w1', hlc: hlcAt(1000, 'dev-a')),
        weightEntryRow('w2', hlc: hlcAt(2000, 'dev-a'), weightKg: 84.0),
      ]);
      final fetched = await serializer.fetchRecords('diverWeightEntries', [
        'w1',
        'w2',
        'missing',
      ]);
      expect(fetched.keys, containsAll(['w1', 'w2']));
      expect(fetched.containsKey('missing'), isFalse);

      // Junction batch upsert (composite junctions are not part of the
      // batched fetchRecords path, matching diveEquipment).
      await serializer.upsertRecords('divePlanEquipment', [planEquipmentRow()]);
      expect(
        await serializer.recordIdsFor('divePlanEquipment'),
        contains('p1|e1'),
      );
    });

    test(
      'deleteRecord removes a weight entry (tombstone apply path)',
      () async {
        final serializer = SyncDataSerializer();
        await serializer.upsertRecord(
          'diverWeightEntries',
          weightEntryRow('w1', hlc: hlcAt(1000, 'dev-a')),
        );
        await serializer.deleteRecord('diverWeightEntries', 'w1');
        expect(
          await serializer.recordIdsFor('diverWeightEntries'),
          isNot(contains('w1')),
        );
      },
    );

    test('incremental export: weight entries filter by their own hlc, plan '
        'equipment keys off the parent plan hlc', () async {
      final serializer = SyncDataSerializer();
      final db = DatabaseService.instance.database;
      await serializer.upsertRecord(
        'diverWeightEntries',
        weightEntryRow('w-old', hlc: hlcAt(1000, 'dev-a')),
      );
      await serializer.upsertRecord(
        'diverWeightEntries',
        weightEntryRow('w-new', hlc: hlcAt(9000, 'dev-a')),
      );
      await serializer.upsertRecord('divePlanEquipment', planEquipmentRow());

      // Parent plan untouched since the watermark: junction stays out.
      await db.customStatement(
        "UPDATE dive_plans SET hlc = '${hlcAt(1000, 'dev-a')}' "
        "WHERE id = 'p1'",
      );
      var changeset = await serializer.exportChangeset(
        deviceId: 'dev-a',
        hlcWatermark: hlcAt(5000, 'dev-a'),
        deletions: const [],
      );
      final entryIds = changeset.data.diverWeightEntries
          .map((r) => r['id'])
          .toSet();
      expect(entryIds, contains('w-new'));
      expect(entryIds, isNot(contains('w-old')));
      expect(changeset.data.divePlanEquipment, isEmpty);

      // Parent plan modified after the watermark: junction rides along.
      await db.customStatement(
        "UPDATE dive_plans SET hlc = '${hlcAt(9000, 'dev-a')}' "
        "WHERE id = 'p1'",
      );
      changeset = await serializer.exportChangeset(
        deviceId: 'dev-a',
        hlcWatermark: hlcAt(5000, 'dev-a'),
        deletions: const [],
      );
      expect(changeset.data.divePlanEquipment, hasLength(1));
    });

    test('deleteAllRecords clears both tables', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'diverWeightEntries',
        weightEntryRow('w1', hlc: hlcAt(1000, 'dev-a')),
      );
      await serializer.upsertRecord('divePlanEquipment', planEquipmentRow());

      await serializer.deleteAllRecords('diverWeightEntries');
      await serializer.deleteAllRecords('divePlanEquipment');

      expect(await serializer.recordIdsFor('diverWeightEntries'), isEmpty);
      expect(await serializer.recordIdsFor('divePlanEquipment'), isEmpty);
    });
  });
}
