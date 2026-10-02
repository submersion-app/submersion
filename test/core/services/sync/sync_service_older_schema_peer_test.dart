import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// Issue #2619: a device on a newer build (a beta) publishes above the schema
/// an older peer (a stable build) can read, so that peer holds every payload
/// it receives from here. The newer device must say so instead of reporting a
/// clean sync while the older one receives nothing.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  SyncService buildService(FakeCloudStorageProvider cloud) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  test('names a peer whose schema is below this build\'s floor', () async {
    final cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'peer-dive', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1');
    await restampPeerWriterSchemaVersion(
      cloud,
      'peer-1',
      writerSchemaVersion: AppDatabase.minimumCompatibleSchemaVersion - 1,
    );
    await restampPeerDeviceName(cloud, 'peer-1', deviceName: 'Stable iPad');

    final result = await buildService(cloud).performSync();

    expect(result.isSuccess, isTrue);
    expect(result.olderSchemaPeerDeviceIds, {'peer-1'});
    expect(result.olderSchemaPeerNames, {'peer-1': 'Stable iPad'});
  });

  test('a peer on this build is not named', () async {
    final cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'peer-dive', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1');

    final result = await buildService(cloud).performSync();

    expect(result.isSuccess, isTrue);
    expect(result.olderSchemaPeerDeviceIds, isEmpty);
  });
}
