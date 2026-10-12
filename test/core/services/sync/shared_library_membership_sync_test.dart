import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

SyncService _service(FakeCloudStorageProvider cloud) => SyncService(
  syncRepository: SyncRepository(),
  serializer: SyncDataSerializer(),
  cloudProvider: cloud,
);

void main() {
  test('a membership reaches a second device of the same profile', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Club',
        backendKind: 's3',
        locationHint: 'bucket/club',
      ),
    );
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await tearDownTestDatabase();

    await setUpTestDatabase();
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    final rows = await SharedLibraryStore().membershipsForDiver('d1');
    expect(rows.single.locationHint, 'bucket/club');
    expect(rows.single.memberId, 'm1');
    await tearDownTestDatabase();
  });

  test('a deleted membership is tombstoned to the peer', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await SharedLibraryStore().deleteMembership('ms1');
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await tearDownTestDatabase();

    await setUpTestDatabase();
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    expect(await SharedLibraryStore().membershipsForDiver('d1'), isEmpty);
    await tearDownTestDatabase();
  });
}
