import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for the per-device "active diver" pointer firing a sync
/// conflict on every two-device exchange.
///
/// Background: at first launch each device auto-creates an owner diver with a
/// fresh UUID and persists the pointer in `settings['active_diver_id']`. The
/// settings table participates in sync; the merge key is the settings `key`
/// column, so two devices that both wrote `active_diver_id` (with their own
/// local UUID) collide on the same key with different values and the sync
/// pipeline correctly flags a conflict.
///
/// The fix is to treat `active_diver_id` as device-local: omit it from the
/// exported payload entirely. The diver *rows* still sync (different IDs, no
/// row-level conflict); only the per-device pointer stays device-local.
void main() {
  group('Sync excludes device-local settings keys', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    test(
      'active_diver_id is not present in the synced settings payload',
      () async {
        final serializer = SyncDataSerializer();

        // Seed active_diver_id via a DIRECT db write -- upsertRecord now
        // filters device-local keys on import, so we must bypass it to get the
        // row into the table and prove the EXPORT filter independently.
        await DatabaseService.instance.database.customStatement(
          "INSERT INTO settings (key, value, updated_at) "
          "VALUES ('active_diver_id', 'diver-A-uuid', 1000)",
        );

        // Seed a second, non-device-local setting so the test also proves the
        // filter is targeted, not a blanket "drop all settings" change.
        await serializer.upsertRecord('settings', {
          'key': 'units_system',
          'value': 'metric',
          'updatedAt': 1000,
        });

        final deviceId = await SyncRepository().getDeviceId();
        await buildService().performSync();

        final payload = await cloudBasePayload(cloud, deviceId);
        final exportedKeys = payload!.data.settings
            .map((s) => s['key'])
            .toSet();

        expect(
          exportedKeys,
          contains('units_system'),
          reason: 'genuine app-wide settings must still sync',
        );
        expect(
          exportedKeys,
          isNot(contains('active_diver_id')),
          reason:
              'active_diver_id is device-local; including it in the payload '
              'causes a settings conflict on every two-device exchange',
        );
      },
    );

    test('importing a device-local settings key does not overwrite the local '
        'value (peer on an older build)', () async {
      final serializer = SyncDataSerializer();
      final db = DatabaseService.instance.database;

      // This device has its own active diver pointer.
      await db.customStatement(
        "INSERT INTO settings (key, value, updated_at) "
        "VALUES ('active_diver_id', 'my-diver', 1000)",
      );

      // A remote payload (from an older build that still exports it) tries to
      // overwrite it with a foreign diver id.
      await serializer.upsertRecord('settings', {
        'key': 'active_diver_id',
        'value': 'foreign-diver',
        'updatedAt': 9999,
      });

      final row = await db
          .customSelect(
            "SELECT value FROM settings WHERE key = 'active_diver_id'",
          )
          .getSingle();
      expect(
        row.read<String>('value'),
        'my-diver',
        reason: 'device-local key must not be overwritten on import',
      );
    });
  });
}
