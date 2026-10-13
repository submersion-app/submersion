import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
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
      const DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: 'L'),
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
          name: 'Reef Survey',
          notes: 'new',
          sharedLibraryId: 'L',
        ),
      );
      await _sync(cloud);
      final site = (await SiteRepository().getSiteById('x'))!;
      expect(site.notes, 'new');
      expect(site.name, 'Reef Survey');
      expect(site.sharedLibraryId, 'L');
      await tearDownTestDatabase();
    },
  );

  test(
    "a profile's hide of a library site follows it to its other devices",
    () async {
      final cloud = FakeCloudStorageProvider();
      await setUpTestDatabase();
      await _addDiver();
      await SiteRepository().createSite(
        const DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: 'L'),
      );
      expect(
        await ProfileHidesRepository().hide(SharedItemKind.site, 'lib', 'd1'),
        isTrue,
      );
      await _sync(cloud);
      await tearDownTestDatabase();

      // The profile's tablet, connected to the same library.
      await setUpTestDatabase();
      await SiteRepository().createSite(
        const DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: 'L'),
      );
      await _sync(cloud);
      expect(
        await ProfileHidesRepository().isHidden(
          SharedItemKind.site,
          'lib',
          'd1',
        ),
        isTrue,
        reason: 'a hide is the profile\'s preference, not library content',
      );
      await tearDownTestDatabase();
    },
  );

  test('an edit on a device without the library keeps the dive at its '
      'library site', () async {
    final cloud = FakeCloudStorageProvider();
    final dir = Directory.systemTemp.createTempSync('row_guard_dive_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final aFile = File(p.join(dir.path, 'a.sqlite'));
    void openA() => DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase(aFile)),
    );

    // The phone holds the shared site library and a dive at one of its sites.
    openA();
    await _addDiver();
    await SiteRepository().createSite(
      const DiveSite(id: 'site-sync', name: 'Reef wall', sharedLibraryId: 'L'),
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(
        site: const DiveSite(id: 'site-sync', name: 'Reef wall'),
      ),
    );
    await _sync(cloud);
    await tearDownTestDatabase();

    // The tablet has no copy of the library site, so the dive lands without
    // it; the diver adds a note there.
    await setUpTestDatabase();
    await _sync(cloud);
    final onTablet = (await DiveRepository().getDiveById('dv'))!;
    await DiveRepository().updateDive(onTablet.copyWith(notes: 'great vis'));
    await _sync(cloud);
    await tearDownTestDatabase();

    // Back on the phone: the note arrives, the library site stays.
    openA();
    await _sync(cloud);
    final rows = await DatabaseService.instance.database
        .customSelect("SELECT site_id, notes FROM dives WHERE id = 'dv'")
        .get();
    expect(rows.single.read<String>('notes'), 'great vis');
    expect(rows.single.read<String?>('site_id'), 'site-sync');
    await tearDownTestDatabase();
  });

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
      const DiveSite(id: 'x', name: 'Reef Survey', sharedLibraryId: 'L'),
    );
    await _sync(cloud);
    expect((await SiteRepository().getSiteById('x'))?.sharedLibraryId, 'L');
    await tearDownTestDatabase();
  });

  test("a peer's tombstone for a child of a library site is ignored", () async {
    final cloud = FakeCloudStorageProvider();
    // Device B lives in a file so it can be reopened as the same device
    // after another device published the tombstone.
    final dir = Directory.systemTemp.createTempSync('row_guard_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bFile = File(p.join(dir.path, 'b.sqlite'));
    Future<void> openB() async {
      DatabaseService.instance.setTestDatabase(
        AppDatabase(NativeDatabase(bFile)),
      );
    }

    // Device A: a personal site with a type, published.
    await setUpTestDatabase();
    await _addDiver();
    await SiteRepository().createSite(const DiveSite(id: 'x', name: 'Mine'));
    final types = await SiteTypeRepository().getAllSiteTypes(diverId: 'd1');
    await SiteClassificationRepository().replaceTypes('x', [types.first.id]);
    await _sync(cloud);
    await tearDownTestDatabase();

    // Device B: receives both rows, then the site joins a library.
    await openB();
    await _sync(cloud);
    await DatabaseService.instance.database.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'L' WHERE id = 'x'",
    );
    await _sync(cloud);
    await tearDownTestDatabase();

    // Device C: holds the personal copy, drops the type, which tombstones
    // the junction row.
    await setUpTestDatabase();
    await _sync(cloud);
    await SiteClassificationRepository().replaceTypes('x', []);
    final logged = await DatabaseService.instance.database
        .customSelect(
          "SELECT 1 FROM deletion_log WHERE entity_type = 'siteSiteTypes'",
        )
        .get();
    expect(logged, isNotEmpty, reason: 'the test needs a child tombstone');
    await _sync(cloud);
    await tearDownTestDatabase();

    // Device B again: the library site keeps its type.
    await openB();
    await _sync(cloud);
    final links = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM site_site_types WHERE site_id = 'x'")
        .get();
    expect(links, hasLength(1));
    await tearDownTestDatabase();
  });

  test('deleting a library row logs no tombstone', () async {
    await setUpTestDatabase();
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Reef Survey', sharedLibraryId: 'L'),
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
      const DiveSite(id: 'lib', name: 'Reef Survey', sharedLibraryId: 'L'),
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
