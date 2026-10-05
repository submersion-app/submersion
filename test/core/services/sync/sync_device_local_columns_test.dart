import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/device_local_fields.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Columns listed in deviceLocalSyncColumns belong to this device: an
/// incoming row, from any peer and through any write path, never changes
/// them (issue #2947).
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(tearDownTestDatabase);

  /// Runs one sync against a fresh fake cloud and reads back the base this
  /// device published.
  Future<SyncPayload> syncedBase() async {
    final cloud = FakeCloudStorageProvider();
    final deviceId = await SyncRepository().getDeviceId();
    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    return (await cloudBasePayload(cloud, deviceId))!;
  }

  group('diveComputers.bluetoothAddress', () {
    Future<Map<String, dynamic>> seedComputer() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO dive_computers (id, name, bluetooth_address, created_at, '
        "updated_at) VALUES ('c1', 'Perdix', 'AA:BB', $now, $now)",
      );
      final row = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals('c1'))).getSingle();
      return row.toJson();
    }

    Future<DiveComputer> storedComputer(String id) => (db.select(
      db.diveComputers,
    )..where((t) => t.id.equals(id))).getSingle();

    test('upsertRecord keeps the local address', () async {
      final local = await seedComputer();
      await serializer.upsertRecord('diveComputers', {
        ...local,
        'name': 'Perdix 2',
        'bluetoothAddress': 'CC:DD',
        'updatedAt': (local['updatedAt'] as int) + 1000,
      });
      final row = await storedComputer('c1');
      expect(row.name, 'Perdix 2');
      expect(row.bluetoothAddress, 'AA:BB');
    });

    test('upsertRecords keeps the local address', () async {
      final local = await seedComputer();
      await serializer.upsertRecords('diveComputers', [
        {...local, 'bluetoothAddress': null},
      ]);
      expect((await storedComputer('c1')).bluetoothAddress, 'AA:BB');
    });

    test('a replace-adopt clear and refill keeps the local address', () async {
      final local = await seedComputer();
      await serializer.deleteAllRecords('diveComputers');
      await serializer.upsertRecords('diveComputers', [
        withoutKeys(local, {'bluetoothAddress'}),
      ]);
      expect((await storedComputer('c1')).bluetoothAddress, 'AA:BB');
    });

    test('the synced base omits the address', () async {
      await seedComputer();
      final payload = await syncedBase();
      final exported = payload.data.diveComputers.single;
      expect(exported, isNot(contains('bluetoothAddress')));
      expect(exported['name'], 'Perdix');
    });

    test('a finished adopt forgets the addresses it remembered', () async {
      await seedComputer();
      final local = (await storedComputer('c1')).toJson();
      // The adopted library has no dive computers, so c1 is gone afterwards.
      const base = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 1,
        deviceId: 'cloud',
        checksum: '',
        data: SyncData(),
        deletions: {},
      );
      final tmpDir = await Directory.systemTemp.createTemp('adopt_forget');
      addTearDown(() => tmpDir.delete(recursive: true));
      final file = File(p.join(tmpDir.path, 'base.json'));
      await file.writeAsBytes(utf8.encode(serializer.serializePayload(base)));
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: serializer,
      ).debugAdoptStreaming([file.path], [base.exportedAt], const []);

      // A later sync brings c1 back: it is new to this device again.
      await serializer.upsertRecord(
        'diveComputers',
        withoutKeys(local, {'bluetoothAddress'}),
      );
      expect((await storedComputer('c1')).bluetoothAddress, isNull);
    });

    test('a computer new to this device has no address', () async {
      final local = await seedComputer();
      await serializer.upsertRecord('diveComputers', {
        ...local,
        'id': 'c2',
        'bluetoothAddress': 'EE:FF',
      });
      expect((await storedComputer('c2')).bluetoothAddress, isNull);
    });
  });

  group('diverSettings notification settings and theme mode', () {
    const deviceLocal = {
      'notificationsEnabled',
      'serviceReminderDays',
      'reminderTime',
      'tripServiceLeadDays',
      'themeMode',
    };

    Future<DiverSetting> storedRow() => (db.select(
      db.diverSettings,
    )..where((t) => t.diverId.equals('d1'))).getSingle();

    /// This device's choices, all different from the column defaults.
    Future<Map<String, dynamic>> seedSettings() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await DiverSettingsRepository().createSettingsForDiver(
        'd1',
        settings: const AppSettings().copyWith(
          themeMode: ThemeMode.dark,
          notificationsEnabled: false,
          serviceReminderDays: [3],
          reminderTime: const TimeOfDay(hour: 6, minute: 15),
          tripServiceLeadDays: 21,
        ),
      );
      return (await storedRow()).toJson();
    }

    /// What a peer on an older build sends: every column, its own values.
    Map<String, dynamic> olderPeerRow(Map<String, dynamic> local) => {
      ...local,
      'themeMode': 'light',
      'notificationsEnabled': true,
      'serviceReminderDays': '[30]',
      'reminderTime': '20:00',
      'tripServiceLeadDays': 2,
      'gfHigh': 70,
      'updatedAt': (local['updatedAt'] as int) + 1000,
    };

    void expectLocalValuesKept(DiverSetting row) {
      expect(row.themeMode, 'dark');
      expect(row.notificationsEnabled, isFalse);
      expect(row.serviceReminderDays, '[3]');
      expect(row.reminderTime, '06:15');
      expect(row.tripServiceLeadDays, 21);
    }

    test('fetchRecord and fetchRecords omit them', () async {
      final local = await seedSettings();
      final id = local['id'] as String;
      final single = await serializer.fetchRecord('diverSettings', id);
      expect(single!.keys.toSet().intersection(deviceLocal), isEmpty);
      expect(single, contains('gfHigh'));
      final batch = await serializer.fetchRecords('diverSettings', [id]);
      expect(batch[id]!.keys.toSet().intersection(deviceLocal), isEmpty);
    });

    test('the synced payload omits them', () async {
      await seedSettings();
      final payload = await syncedBase();
      final exported = payload.data.diverSettings.single;
      expect(exported.keys.toSet().intersection(deviceLocal), isEmpty);
      expect(exported, contains('themePreset'));
      expect(exported, contains('mapStyle'));
      expect(exported, contains('locale'));
    });

    test(
      'upsertRecord of an older peer row keeps them and applies the rest',
      () async {
        final local = await seedSettings();
        await serializer.upsertRecord('diverSettings', olderPeerRow(local));
        final row = await storedRow();
        expectLocalValuesKept(row);
        expect(row.gfHigh, 70);
      },
    );

    test('upsertRecords of an older peer row keeps them', () async {
      final local = await seedSettings();
      await serializer.upsertRecords('diverSettings', [olderPeerRow(local)]);
      final row = await storedRow();
      expectLocalValuesKept(row);
      expect(row.gfHigh, 70);
    });

    test('a replace-adopt clear and refill keeps them', () async {
      final local = await seedSettings();
      await serializer.deleteAllRecords('diverSettings');
      await serializer.upsertRecords('diverSettings', [
        withoutKeys(olderPeerRow(local), deviceLocal),
      ]);
      final row = await storedRow();
      expectLocalValuesKept(row);
      expect(row.gfHigh, 70);
    });

    test('a settings row new to this device takes the defaults', () async {
      final local = await seedSettings();
      await db.delete(db.diverSettings).go();
      await serializer.upsertRecord('diverSettings', olderPeerRow(local));
      final row = await storedRow();
      expect(row.themeMode, 'system');
      expect(row.gfHigh, 70);
    });
  });

  // A new entry in deviceLocalSyncColumns must work in every path that reads
  // the device-local values, not throw the first time a sync reaches it.
  test(
    'every device-local entity survives the adopt and refill reads',
    () async {
      for (final entityType in deviceLocalSyncColumns.keys) {
        await serializer.deleteAllRecords(entityType);
        await serializer.upsertRecords(entityType, const []);
        try {
          await serializer.upsertRecords(entityType, [
            {'id': 'absent-$entityType'},
          ]);
        } on StateError catch (e) {
          fail('$entityType: $e');
        } catch (_) {
          // A bare row fails the table's own constraints; only the
          // device-local read must not be the failure.
        }
      }
    },
  );
}

Map<String, dynamic> withoutKeys(Map<String, dynamic> row, Set<String> keys) =>
    {...row}..removeWhere((key, _) => keys.contains(key));
