import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../core/database/change_log/change_log_support.dart';
import '../../helpers/test_database.dart';

/// A revert is only worth anything if it reaches the diver's other devices,
/// so each case here edits on one device, syncs, reverts, syncs again and
/// reads the other device.
void main() {
  late AppDatabase laptop;
  late AppDatabase phone;
  var clock = 1700000000000;

  void use(AppDatabase db) {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
    SyncClock.instance.configure(
      nodeId: identical(db, laptop) ? 'laptop' : 'phone',
      now: () => clock += 1000,
    );
  }

  /// A full export from [from], applied on [to] the way a pull applies it.
  Future<void> sync(AppDatabase from, AppDatabase to) async {
    clock += 60000;
    use(from);
    final serializer = SyncDataSerializer();
    final payload = await serializer.exportData(
      deviceId: identical(from, laptop) ? 'laptop' : 'phone',
      deletions: await SyncRepository().getAllDeletions(),
    );
    use(to);
    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugApplyPayload(payload, lastSync: DateTime(2020));
    use(laptop);
    // Whatever comes next is a later save, not the same one: the grouping
    // window runs on real time, and these steps take milliseconds.
    await ChangeLogRepository().settleAll();
    await laptop.customStatement(
      'UPDATE change_log_operations SET ended_at = ended_at - 60000',
    );
  }

  Future<void> markPending(String entity, String id) =>
      SyncRepository().markRecordPending(
        entityType: entity,
        recordId: id,
        localUpdatedAt: clock,
      );

  /// Reverts the newest entry on the laptop.
  Future<void> revertNewest() async {
    final repository = ChangeLogRepository();
    await repository.settleAll();
    final row = await laptop
        .customSelect(
          'SELECT id FROM change_log_operations WHERE event_count > 0 '
          'ORDER BY last_event_id DESC LIMIT 1',
        )
        .getSingle();
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    final result = await service.execute(
      await service.planOperation(row.read<String>('id')),
    );
    expect(result.reverted, greaterThan(0));
  }

  setUp(() async {
    laptop = createTestDatabase();
    phone = createTestDatabase();
    use(laptop);
    await insertDiver(laptop, 'me');
    await insertDive(laptop, 'dive', diverId: 'me', notes: 'Calm');
    await markPending('divers', 'me');
    await markPending('dives', 'dive');
    await sync(laptop, phone);
  });

  tearDown(() async {
    SyncClock.instance.reset();
    DatabaseService.instance.resetForTesting();
    await laptop.close();
    await phone.close();
  });

  Future<Object?> read(AppDatabase db, String sql) async {
    final row = await db.customSelect(sql).getSingleOrNull();
    return row?.data.values.first;
  }

  test('a revert of a root row reaches the peer', () async {
    await laptop.customStatement(
      "UPDATE dives SET notes = 'Wrong', updated_at = $clock WHERE id = 'dive'",
    );
    await markPending('dives', 'dive');
    await sync(laptop, phone);
    expect(await read(phone, "SELECT notes FROM dives"), 'Wrong');

    await revertNewest();
    await sync(laptop, phone);

    expect(await read(phone, "SELECT notes FROM dives"), 'Calm');
  });

  test('a revert of a clockless child reaches the peer', () async {
    await laptop
        .into(laptop.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await markPending('diveTanks', 'tank');
    await sync(laptop, phone);
    await ChangeLogRepository().settleAll();
    await laptop.customStatement(
      "UPDATE dive_tanks SET start_pressure = 200 WHERE id = 'tank'",
    );
    await markPending('diveTanks', 'tank');
    await sync(laptop, phone);
    expect(await read(phone, 'SELECT start_pressure FROM dive_tanks'), 200);

    await revertNewest();
    await sync(laptop, phone);

    expect(await read(phone, 'SELECT start_pressure FROM dive_tanks'), isNull);
  });

  test('a restored pair junction reaches the peer', () async {
    await laptop.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at) '
      "VALUES ('tag', 'me', 'Night', 0, 0)",
    );
    await laptop.customStatement(
      "INSERT INTO dive_tags (id, dive_id, tag_id, created_at) "
      "VALUES ('link', 'dive', 'tag', 0)",
    );
    await markPending('tags', 'tag');
    await markPending('diveTags', 'link');
    await sync(laptop, phone);
    await ChangeLogRepository().settleAll();

    await laptop.customStatement("DELETE FROM dive_tags WHERE id = 'link'");
    await SyncRepository().logDeletion(
      entityType: 'diveTags',
      recordId: 'link',
    );
    await sync(laptop, phone);
    expect(await read(phone, 'SELECT COUNT(*) FROM dive_tags'), 0);

    await revertNewest();
    await sync(laptop, phone);

    expect(await read(phone, 'SELECT COUNT(*) FROM dive_tags'), 1);
  });

  test('a restored share reaches the peer', () async {
    await laptop.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('site', 'me', 'Reef', 0, 0)",
    );
    await insertDiver(laptop, 'friend');
    await laptop.customStatement(
      'INSERT INTO site_shares (id, site_id, diver_id, created_at) '
      "VALUES ('share', 'site', 'friend', 0)",
    );
    await markPending('diveSites', 'site');
    await markPending('divers', 'friend');
    await markPending('siteShares', 'share');
    await sync(laptop, phone);
    expect(await read(phone, 'SELECT COUNT(*) FROM site_shares'), 1);
    await ChangeLogRepository().settleAll();

    await laptop.customStatement("DELETE FROM site_shares WHERE id = 'share'");
    await SyncRepository().logDeletion(
      entityType: 'siteShares',
      recordId: 'share',
    );
    await sync(laptop, phone);
    expect(await read(phone, 'SELECT COUNT(*) FROM site_shares'), 0);

    await revertNewest();
    await sync(laptop, phone);

    expect(await read(phone, 'SELECT COUNT(*) FROM site_shares'), 1);
  });

  test('a revert of a fact group column reaches the peer', () async {
    await laptop.customStatement(
      'INSERT INTO diver_settings (id, diver_id, dive_list_sort, created_at, '
      "updated_at) VALUES ('s1', 'me', 'old', 0, 0)",
    );
    await markPending('diverSettings', 's1');
    await sync(laptop, phone);
    await laptop.customStatement(
      "UPDATE diver_settings SET dive_list_sort = 'new'",
    );
    await SyncRepository().markRecordPending(
      entityType: 'diverSettings',
      recordId: 's1',
      localUpdatedAt: clock,
      alsoStamp: const [SyncFactGroups.diverSettingsListArrangement],
      stampClock: false,
    );
    await sync(laptop, phone);
    expect(
      await read(phone, 'SELECT dive_list_sort FROM diver_settings'),
      'new',
    );

    await laptop.customStatement(
      'INSERT INTO change_log_events (operation_id, table_name, record_id, '
      "action, changed_at, schema_version, settled) VALUES ('op', "
      "'diver_settings', 's1', 'U', 1, ${AppDatabase.currentSchemaVersion}, 1)",
    );
    final event = await read(laptop, 'SELECT MAX(id) FROM change_log_events');
    await laptop.customStatement(
      'INSERT INTO change_log_fields (event_id, column_name, old_value, '
      "new_value) VALUES (?, 'dive_list_sort', 'old', 'new')",
      [event],
    );
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await service.execute(
      await service.planField(event! as int, 'dive_list_sort'),
    );
    await sync(laptop, phone);

    expect(
      await read(phone, 'SELECT dive_list_sort FROM diver_settings'),
      'old',
    );
  });

  test('a restored dive reaches the peer', () async {
    await laptop
        .into(laptop.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await markPending('diveTanks', 'tank');
    await sync(laptop, phone);
    await ChangeLogRepository().settleAll();
    await laptop.customStatement('DELETE FROM change_log_events');
    await laptop.customStatement('DELETE FROM change_log_fields');
    await laptop.customStatement('DELETE FROM change_log_operations');

    await DiveRepository().deleteDive('dive');
    await sync(laptop, phone);
    expect(await read(phone, 'SELECT COUNT(*) FROM dives'), 0);

    await revertNewest();
    await sync(laptop, phone);

    expect(await read(phone, 'SELECT notes FROM dives'), 'Calm');
    expect(await read(phone, 'SELECT COUNT(*) FROM dive_tanks'), 1);
  });
}
