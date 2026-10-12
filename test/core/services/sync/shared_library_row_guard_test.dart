import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

SyncService _svc(FakeCloudStorageProvider cloud) => SyncService(
  syncRepository: SyncRepository(),
  serializer: SyncDataSerializer(),
  cloudProvider: cloud,
);

Future<void> _sync(FakeCloudStorageProvider cloud) async {
  expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
}

Future<void> _addDiver() => DiverRepository().createDiver(
  Diver(
    id: 'd1',
    name: 'Ann',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  test('a library site and its children are never exported', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await _addDiver();
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: 'L'),
    );
    final types = await SiteTypeRepository().getAllSiteTypes(diverId: 'd1');
    await SiteClassificationRepository().replaceTypes('lib', [types.first.id]);
    await SiteRepository().createSite(const DiveSite(id: 'mine', name: 'Mine'));
    await _sync(cloud);
    await tearDownTestDatabase();

    await setUpTestDatabase();
    await _sync(cloud);
    expect(await SiteRepository().getSiteById('mine'), isNotNull);
    expect(await SiteRepository().getSiteById('lib'), isNull);
    final links = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM site_site_types WHERE site_id = 'lib'")
        .get();
    expect(links, isEmpty);
    await tearDownTestDatabase();
  });

  test(
    'a peer\'s stale personal copy never overwrites a library row',
    () async {
      final cloud = FakeCloudStorageProvider();
      await setUpTestDatabase();
      await SiteRepository().createSite(
        const DiveSite(id: 'x', name: 'Stale', notes: 'old'),
      );
      await _sync(cloud);
      await tearDownTestDatabase();

      await setUpTestDatabase();
      await SiteRepository().createSite(
        const DiveSite(
          id: 'x',
          name: 'Club',
          notes: 'new',
          sharedLibraryId: 'L',
        ),
      );
      await _sync(cloud);
      final site = (await SiteRepository().getSiteById('x'))!;
      expect(site.notes, 'new');
      expect(site.name, 'Club');
      expect(site.sharedLibraryId, 'L');
      await tearDownTestDatabase();
    },
  );

  test('a peer\'s tombstone never deletes a library row', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await SiteRepository().createSite(const DiveSite(id: 'x', name: 'Stale'));
    await _sync(cloud);
    await SiteRepository().deleteSite('x');
    await _sync(cloud);
    await tearDownTestDatabase();

    await setUpTestDatabase();
    await SiteRepository().createSite(
      const DiveSite(id: 'x', name: 'Club', sharedLibraryId: 'L'),
    );
    await _sync(cloud);
    expect((await SiteRepository().getSiteById('x'))?.sharedLibraryId, 'L');
    await tearDownTestDatabase();
  });

  test('deleting a library row logs no tombstone', () async {
    await setUpTestDatabase();
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Club', sharedLibraryId: 'L'),
    );
    expect(await SiteRepository().deleteSite('lib'), isTrue);
    final rows = await DatabaseService.instance.database
        .customSelect(
          "SELECT 1 FROM deletion_log WHERE entity_type = 'diveSites' "
          "AND record_id = 'lib'",
        )
        .get();
    expect(rows, isEmpty);
    expect(await SiteRepository().getSiteById('lib'), isNull);
    await tearDownTestDatabase();
  });

  test('a mixed bulk delete tombstones only the personal rows', () async {
    await setUpTestDatabase();
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Club', sharedLibraryId: 'L'),
    );
    await SiteRepository().createSite(const DiveSite(id: 'mine', name: 'Mine'));
    await SiteRepository().bulkDeleteSites(['lib', 'mine']);
    final rows = await DatabaseService.instance.database
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'diveSites'",
        )
        .get();
    expect(rows.map((r) => r.read<String>('record_id')), ['mine']);
    await tearDownTestDatabase();
  });
}
