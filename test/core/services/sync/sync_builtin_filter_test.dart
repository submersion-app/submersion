import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Built-in catalog rows (species, dive types, field presets) are re-seeded
/// identically on every device and are immutable, so they must NOT sync:
/// shipping them only risks cross-device ID collisions and payload bloat.
/// User-created rows in the same tables must still sync.
void main() {
  group('Built-in catalog rows are excluded from sync', () {
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

    test('built-in species are excluded, custom species are kept', () async {
      final serializer = SyncDataSerializer();

      await serializer.upsertRecord('species', {
        'id': 'sp_builtin_1',
        'commonName': 'Whale Shark',
        'category': 'shark',
        'isBuiltIn': true,
      });
      await serializer.upsertRecord('species', {
        'id': 'sp_custom_1',
        'commonName': 'My Local Critter',
        'category': 'fish',
        'isBuiltIn': false,
      });

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();

      final payload = await cloudBasePayload(cloud, deviceId);
      final ids = payload!.data.species.map((s) => s['id']).toSet();

      expect(ids, contains('sp_custom_1'));
      expect(
        ids,
        isNot(contains('sp_builtin_1')),
        reason: 'built-in species must not be exported',
      );
    });

    test(
      'built-in dive types are excluded, custom dive types are kept',
      () async {
        final serializer = SyncDataSerializer();

        await serializer.upsertRecord('diveTypes', {
          'id': 'dt_builtin_1',
          'name': 'Recreational',
          'isBuiltIn': true,
          'sortOrder': 0,
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await serializer.upsertRecord('diveTypes', {
          'id': 'dt_custom_1',
          'name': 'Cenote',
          'isBuiltIn': false,
          'sortOrder': 1,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final deviceId = await SyncRepository().getDeviceId();
        await buildService().performSync();

        final payload = await cloudBasePayload(cloud, deviceId);
        final ids = payload!.data.diveTypes.map((t) => t['id']).toSet();

        expect(ids, contains('dt_custom_1'));
        expect(
          ids,
          isNot(contains('dt_builtin_1')),
          reason: 'built-in dive types must not be exported',
        );
      },
    );
  });
}
