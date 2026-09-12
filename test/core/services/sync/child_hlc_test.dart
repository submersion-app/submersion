import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/bound_variables.dart';
import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Children with no clock of their own (a dive's tanks, gear links, events
/// and the rest) were applied as blind upserts, so a stale full row from a
/// peer overwrote a newer local edit to the same child. Each now carries an
/// HLC, stamped when it is marked pending, and the merge refuses a remote
/// copy strictly older than the local one. A tie or a missing clock on
/// either side still applies, as the blind upsert always did, so a writer
/// that did not restamp still propagates.
void main() {
  late AppDatabase db;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    db = await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  test('every parent-gated child is a stamped HLC target with a column', () {
    final withHlc = {
      for (final t in db.allTables)
        if (t.$columns.any((c) => c.name == 'hlc')) t.actualTableName,
    };
    for (final type in SyncDataSerializer.parentGatedChildEntities) {
      final target = SyncRepository.hlcTargets[type];
      expect(target, isNotNull, reason: '$type is not an HLC target');
      expect(withHlc, contains(target!.table), reason: type);
      expect(
        SyncDataSerializer.parentGatedTables[type],
        target.table,
        reason: 'the batched read and the stamp must name one table',
      );
    }
  });

  Future<String?> hlcOf(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<String?>('hlc');

  test('marking a child pending stamps its clock, composite keys too', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1')",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d1', 'e1')",
    );

    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 't1',
      localUpdatedAt: 1,
    );
    await SyncRepository().markRecordPending(
      entityType: 'diveEquipment',
      recordId: 'd1|e1',
      localUpdatedAt: 1,
    );

    expect(
      await hlcOf("SELECT hlc FROM dive_tanks WHERE id = 't1'"),
      isNotNull,
    );
    expect(
      await hlcOf(
        "SELECT hlc FROM dive_equipment WHERE dive_id = 'd1' "
        "AND equipment_id = 'e1'",
      ),
      isNotNull,
    );
  });

  test('children are fetched in batches, composite keys included', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1'), ('t2', 'd1')",
    );
    await db.customStatement(
      'INSERT INTO dive_equipment (dive_id, equipment_id) '
      "VALUES ('d1', 'e1'), ('d1', 'e2')",
    );
    final serializer = SyncDataSerializer();

    final tanks = await serializer.fetchRecords('diveTanks', ['t1', 't2', 'x']);
    expect(tanks.keys.toSet(), {'t1', 't2'});
    expect(tanks['t1'], await serializer.fetchRecord('diveTanks', 't1'));

    final gear = await serializer.fetchRecords('diveEquipment', [
      'd1|e1',
      'd1|e2',
      'd1|nope',
    ]);
    expect(gear.keys.toSet(), {'d1|e1', 'd1|e2'});
    expect(
      gear['d1|e1'],
      await serializer.fetchRecord('diveEquipment', 'd1|e1'),
    );
  });

  test(
    'a batch of composite keys binds within SQLite\'s variable limit',
    () async {
      // Each composite key binds two variables, so a 900-key batch of gear
      // links bound 1800.
      await tearDownTestDatabase();
      setUpLoggingTestDatabase();
      for (final type in ['diveEquipment', 'diveTanks']) {
        final ids = [for (var i = 0; i < 2000; i++) 'd$i|e$i'];
        final most = await maxBoundVariables(
          () => SyncDataSerializer().fetchRecords(type, ids),
        );
        expect(most, lessThanOrEqualTo(sqliteVariableLimit), reason: type);
      }
    },
  );

  group('a peer\'s copy of a tank', () {
    late Map<String, dynamic> local;
    late Hlc localHlc;

    setUp(() async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await db.customStatement(
        "INSERT INTO dive_tanks (id, dive_id, volume) VALUES ('t1', 'd1', 11.1)",
      );
      await SyncRepository().markRecordPending(
        entityType: 'diveTanks',
        recordId: 't1',
        localUpdatedAt: 1,
      );
      local = (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
      localHlc = Hlc.parse(local['hlc'] as String);
      // This device has published; what follows is a peer's payload.
      await SyncRepository().clearAllSyncRecords();
    });

    Future<double?> pull(Map<String, dynamic> theirs) async {
      final data = SyncData(diveTanks: [theirs]);
      await seedPeerBaseFromPayload(
        cloud,
        'peer-b',
        SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'peer-b',
          checksum: sha256
              .convert(utf8.encode(jsonEncode(data.toJson())))
              .toString(),
          data: data,
          deletions: const {},
        ),
      );
      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      ).performSync();
      expect(result.status, isNot(SyncResultStatus.error));
      return (await SyncDataSerializer().fetchRecord(
            'diveTanks',
            't1',
          ))!['volume']
          as double?;
    }

    Hlc shifted(int ms) =>
        Hlc(localHlc.physicalTime + ms, localHlc.counter, 'peer-b');

    test('strictly older does not overwrite the newer local edit', () async {
      final volume = await pull({
        ...local,
        'volume': 7.0,
        'hlc': shifted(-1000).toString(),
      });
      expect(volume, 11.1);
    });

    test('newer applies', () async {
      final volume = await pull({
        ...local,
        'volume': 7.0,
        'hlc': shifted(1000).toString(),
      });
      expect(volume, 7.0);
    });

    test('an exact tie applies, as the blind upsert did', () async {
      // A writer that changed the row without restamping it still carries
      // the clock both devices share; its change must still land.
      final volume = await pull({...local, 'volume': 7.0});
      expect(volume, 7.0);
    });

    test('a copy with no clock applies, as the blind upsert did', () async {
      final volume = await pull({...local, 'volume': 7.0, 'hlc': null});
      expect(volume, 7.0);
    });
  });
}
