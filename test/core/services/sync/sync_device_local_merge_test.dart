import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Device-local values (issue #2947) through a real merge: a peer on an
/// older build still sends them, and neither its values nor the difference
/// may reach this device.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
    SyncClock.instance.reset();
  });

  SyncPayload payload(
    SyncData data,
    int exportedAt, {
    Map<String, List<SyncDeletion>> deletions = const {},
  }) => SyncPayload(
    version: syncFormatVersion,
    exportedAt: exportedAt,
    deviceId: 'older-peer',
    checksum: sha256.convert(utf8.encode(jsonEncode(data.toJson()))).toString(),
    data: data,
    deletions: deletions,
  );

  Future<SyncResult> syncWithPeer(
    SyncData data, {
    DateTime? lastSync,
    Map<String, List<SyncDeletion>> deletions = const {},
  }) async {
    final cloud = FakeCloudStorageProvider();
    await SyncRepository().resetSyncState();
    if (lastSync != null) await SyncRepository().updateLastSyncTime(lastSync);
    await seedPeerBaseFromPayload(
      cloud,
      'older-peer',
      payload(data, 9000, deletions: deletions),
    );
    return SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
  }

  test(
    'a full older-peer settings row applies its synced columns only',
    () async {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-1', 'Diver', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO diver_settings (id, diver_id, created_at, updated_at, "
        "theme_mode, notifications_enabled, reminder_time, gf_high, hlc) "
        "VALUES ('ds-1', 'diver-1', 1, 1, 'dark', 0, '06:15', 85, "
        "'${const Hlc(1000, 0, 'local')}')",
      );
      final local = (await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-1'))).getSingle()).toJson();

      final result = await syncWithPeer(
        SyncData(
          diverSettings: [
            {
              ...local,
              'themeMode': 'light',
              'notificationsEnabled': true,
              'reminderTime': '20:00',
              'gfHigh': 70,
              'updatedAt': 2,
              'hlc': const Hlc(2000, 0, 'older-peer').toString(),
            },
          ],
        ),
      );

      expect(result.status, isNot(SyncResultStatus.error));
      final after = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-1'))).getSingle();
      expect(after.gfHigh, 70);
      expect(after.themeMode, 'dark');
      expect(after.notificationsEnabled, isFalse);
      expect(after.reminderTime, '06:15');
      expect(await SyncRepository().getConflictRecords(), isEmpty);
    },
  );

  test('a peer copy of a nav layout key raises no conflict', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Written on this device after the upgrade: device-local, so never
    // stamped with a sync clock.
    await db.customStatement(
      "INSERT INTO settings (key, value, updated_at) "
      "VALUES ('nav_primary_ids', '[\"dives\"]', $now)",
    );

    final result = await syncWithPeer(
      SyncData(
        settings: [
          {
            'key': 'nav_primary_ids',
            'value': '["sites"]',
            'updatedAt': now + 1000,
            'hlc': Hlc(now + 1000, 0, 'older-peer').toString(),
          },
        ],
      ),
      // Both copies changed since the last sync, and only the peer's carries
      // a clock: the pre-HLC rule that raises a conflict for a real setting.
      lastSync: DateTime.fromMillisecondsSinceEpoch(now - 60000),
    );

    expect(result.status, isNot(SyncResultStatus.error));
    expect(await SyncRepository().getConflictRecords(), isEmpty);
    final value = await db
        .customSelect(
          "SELECT value FROM settings WHERE key = 'nav_primary_ids'",
        )
        .getSingle();
    expect(value.read<String>('value'), '["dives"]');
  });

  test(
    'a conflict an older build stored shows no device-local column',
    () async {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-1', 'Diver', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO diver_settings (id, diver_id, created_at, updated_at, "
        "theme_mode) VALUES ('ds-1', 'diver-1', 1, 1, 'dark')",
      );
      final local = (await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-1'))).getSingle()).toJson();
      // Stored before the upgrade, when the remote copy carried every column.
      await SyncRepository().markRecordConflict(
        entityType: 'diverSettings',
        recordId: 'ds-1',
        conflictDataJson: jsonEncode({...local, 'themeMode': 'light'}),
        localUpdatedAt: 1,
      );

      final conflicts = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: FakeCloudStorageProvider(),
      ).getConflicts();

      expect(conflicts.single.remoteData, isNot(contains('themeMode')));
      expect(conflicts.single.localData, isNot(contains('themeMode')));
    },
  );

  test('a conflict an older build stored for a nav key is not shown', () async {
    await db.customStatement(
      "INSERT INTO settings (key, value, updated_at) "
      "VALUES ('nav_primary_ids', '[\"dives\"]', 1)",
    );
    // Stored before the upgrade, when the nav order still synced.
    await SyncRepository().markRecordConflict(
      entityType: 'settings',
      recordId: 'nav_primary_ids',
      conflictDataJson: jsonEncode({
        'key': 'nav_primary_ids',
        'value': '["sites"]',
        'updatedAt': 2,
      }),
      localUpdatedAt: 1,
    );

    final conflicts = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: FakeCloudStorageProvider(),
    ).getConflicts();

    expect(conflicts, isEmpty);
    expect(await SyncRepository().getConflictCount(), 0);
  });

  test(
    'a peer tombstone for a nav layout key leaves the local value',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Set before the last sync and untouched since, so nothing protects it
      // from an older peer's tombstone but its being device-local.
      await db.customStatement(
        "INSERT INTO settings (key, value, updated_at) "
        "VALUES ('nav_primary_ids', '[\"dives\"]', ${now - 120000})",
      );

      final result = await syncWithPeer(
        const SyncData(),
        deletions: {
          'settings': [
            SyncDeletion(
              id: 'nav_primary_ids',
              deletedAt: now + 1000,
              hlc: Hlc(now + 1000, 0, 'older-peer').toString(),
            ),
          ],
        },
        lastSync: DateTime.fromMillisecondsSinceEpoch(now - 60000),
      );

      expect(result.status, isNot(SyncResultStatus.error));
      final rows = await db
          .customSelect(
            "SELECT value FROM settings WHERE key = 'nav_primary_ids'",
          )
          .get();
      expect(rows.single.read<String>('value'), '["dives"]');
      expect(await SyncRepository().getConflictRecords(), isEmpty);
      expect(
        (await SyncRepository().getAllDeletions()).where(
          (d) => d.entityType == 'settings' && d.recordId == 'nav_primary_ids',
        ),
        isEmpty,
        reason: 'a device-local key must not be tombstoned here either',
      );
    },
  );
}
