import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/peer_pull.dart';
import '../../../helpers/test_database.dart';

/// A peer that clears a column on a child row (a re-parse dropping a stale
/// transmitter serial, a split clearing computer_id) used to leave the old
/// value everywhere else: the upsert drops nulls (#2644). A copy whose clock
/// is strictly newer now writes its explicit nulls; a tie, a missing clock
/// or an omitted key still leaves the local value alone.
void main() {
  late AppDatabase db;
  late FakeCloudStorageProvider cloud;
  late Map<String, dynamic> local;
  late Hlc localHlc;

  setUp(() async {
    db = await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, volume, transmitter_serial) "
      "VALUES ('t1', 'd1', 11.1, 'SER-1')",
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
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<Map<String, dynamic>> pull(Map<String, dynamic> theirs) async {
    final result = await pullPeerPayload(cloud, SyncData(diveTanks: [theirs]));
    expect(result.status, isNot(SyncResultStatus.error));
    return (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
  }

  Hlc shifted(int ms) =>
      Hlc(localHlc.physicalTime + ms, localHlc.counter, 'peer-b');

  Future<void> dropLocalClock() =>
      db.customStatement("UPDATE dive_tanks SET hlc = NULL WHERE id = 't1'");

  test('a strictly newer copy clears the column it sets to null', () async {
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(1000).toString(),
    });
    expect(row['transmitterSerial'], isNull);
    expect(row['volume'], 11.1, reason: 'only the explicit null clears');
  });

  test('a stamped copy clears a row that has no clock yet', () async {
    await dropLocalClock();
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(1000).toString(),
    });
    expect(row['transmitterSerial'], isNull);
  });

  test('an exact tie (own base re-applied) keeps the value', () async {
    final row = await pull({...local, 'transmitterSerial': null});
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a copy with no clock keeps the value', () async {
    final row = await pull({...local, 'transmitterSerial': null, 'hlc': null});
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('an omitted key keeps the value', () async {
    final theirs = {...local, 'hlc': shifted(1000).toString()}
      ..remove('transmitterSerial');
    final row = await pull(theirs);
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a strictly older copy is skipped, clears included', () async {
    final row = await pull({
      ...local,
      'transmitterSerial': null,
      'hlc': shifted(-1000).toString(),
    });
    expect(row['transmitterSerial'], 'SER-1');
  });

  test(
    'a pending local row that keeps its own fields is not cleared',
    () async {
      // An unpublished local edit with no clock to order it against the
      // peer's: the merge skips the peer's copy of a row it cannot order
      // (the pending-row skip), so no clear may land either.
      await SyncRepository().markRecordPending(
        entityType: 'diveTanks',
        recordId: 't1',
        localUpdatedAt: 2,
      );
      await dropLocalClock();
      final row = await pull({
        ...local,
        'transmitterSerial': null,
        'hlc': shifted(1000).toString(),
      });
      expect(row['transmitterSerial'], 'SER-1');
    },
  );

  test('a failing clear rolls the payload back', () async {
    // Makes the clear pass itself fail after the upsert has landed.
    await db.customStatement(
      'CREATE TEMP TRIGGER fail_clear BEFORE UPDATE OF transmitter_serial '
      'ON dive_tanks WHEN NEW.transmitter_serial IS NULL '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    addTearDown(() => db.customStatement('DROP TRIGGER IF EXISTS fail_clear'));
    await pullPeerPayload(
      cloud,
      SyncData(
        diveTanks: [
          {
            ...local,
            'transmitterSerial': null,
            'hlc': shifted(1000).toString(),
          },
        ],
      ),
    );
    final row = (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
    // Rolled back: the peer's clock did not land, so the next sync re-pulls
    // the changeset and the clear still wins then.
    expect(row['hlc'], local['hlc']);
    expect(row['transmitterSerial'], 'SER-1');

    // With the fault gone, the next sync pulls the same changeset again and
    // the clear lands.
    await db.customStatement('DROP TRIGGER fail_clear');
    final retry = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(retry.status, isNot(SyncResultStatus.error));
    final after = (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
    expect(after['transmitterSerial'], isNull);
  });

  test(
    'a pending local row with a clock takes a newer copy, clear included',
    () async {
      // Both clocks present, so the ordinary resolution orders them and the
      // peer's newer copy wins the row, its clear with it.
      await SyncRepository().markRecordPending(
        entityType: 'diveTanks',
        recordId: 't1',
        localUpdatedAt: 2,
      );
      final pending = Hlc.parse(
        (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!['hlc']
            as String,
      );
      final row = await pull({
        ...local,
        'transmitterSerial': null,
        'hlc': Hlc(pending.physicalTime + 1000, 0, 'peer-b').toString(),
      });
      expect(row['transmitterSerial'], isNull);
    },
  );

  test('a newer copy linking gear deleted here leaves no link', () async {
    // The parent-deletion guard nulls a nullable reference to a parent this
    // device deleted, and from a newer copy that null is a clear. The merge's
    // dangling-reference repair nulls the same link independently (the
    // parent is always missing here), so this pins the outcome both give: no
    // link to deleted gear, and no failed sync. Here the gear was deleted
    // without the set-null cascade, as a library from before it was.
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Cylinder', 'tank', 1, 1)",
    );
    await db.customStatement(
      "UPDATE dive_tanks SET equipment_id = 'e1' WHERE id = 't1'",
    );
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement("DELETE FROM equipment WHERE id = 'e1'");
    await db.customStatement('PRAGMA foreign_keys = ON');
    await SyncRepository().logDeletion(entityType: 'equipment', recordId: 'e1');

    final row = await pull({
      ...local,
      'equipmentId': 'e1',
      'hlc': shifted(1000).toString(),
    });
    expect(row['equipmentId'], isNull);
  });
}
