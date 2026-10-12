import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(
        id: 'lib',
        name: 'Club',
        hazards: 'h',
        sharedLibraryId: 'L',
      ),
    );
    await SharedLibraryStore().putSiteState(
      const SharedSiteState(siteId: 'lib', libraryId: 'L'),
    );
  });

  tearDown(tearDownTestDatabase);

  test(
    'a site with a dive survives as a personal site under a new id',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(
          site: const DiveSite(id: 'lib', name: 'Club'),
        ),
      );
      await SiteFeatureRepository().addFeature(
        siteId: 'lib',
        typeName: 'mooring',
        latitude: 1,
        longitude: 2,
      );
      final newId = await SiteDetacher().detachOrRemove(
        siteId: 'lib',
        ownerDiverId: 'd1',
      );
      expect(newId, isNotNull);
      expect(newId, isNot('lib'));
      expect(await SiteRepository().getSiteById('lib'), isNull);
      final kept = (await SiteRepository().getSiteById(newId!))!;
      expect(kept.sharedLibraryId, isNull);
      expect(kept.diverId, 'd1');
      expect(kept.isShared, isTrue, reason: 'visible to every local profile');
      expect(kept.name, 'Club');
      expect(kept.hazards, 'h');
      final dive = (await DiveRepository().getDiveById('dv'))!;
      expect(dive.site?.id, newId);
      expect(
        (await SiteFeatureRepository().getFeaturesForSite(
          newId,
        )).single.typeName,
        'mooring',
      );
      expect(await SharedLibraryStore().getSiteState('lib'), isNull);
      final rows = await DatabaseService.instance.database
          .customSelect(
            "SELECT 1 FROM deletion_log WHERE entity_type = 'diveSites' "
            "AND record_id = 'lib'",
          )
          .get();
      expect(rows, isEmpty, reason: 'no personal tombstone for a library row');
    },
  );

  test('an unlinked site is removed without a tombstone', () async {
    expect(
      await SiteDetacher().detachOrRemove(siteId: 'lib', ownerDiverId: 'd1'),
      isNull,
    );
    expect(await SiteRepository().getSiteById('lib'), isNull);
    expect(await SharedLibraryStore().getSiteState('lib'), isNull);
    final rows = await DatabaseService.instance.database
        .customSelect(
          "SELECT 1 FROM deletion_log WHERE entity_type = 'diveSites' "
          "AND record_id = 'lib'",
        )
        .get();
    expect(rows, isEmpty);
  });

  test('keepState leaves the state row for the tombstone upload', () async {
    await SiteDetacher().detachOrRemove(
      siteId: 'lib',
      ownerDiverId: 'd1',
      keepState: true,
    );
    expect(await SiteRepository().getSiteById('lib'), isNull);
    expect(await SharedLibraryStore().getSiteState('lib'), isNotNull);
  });

  test('a missing row only clears the state', () async {
    await SiteRepository().deleteSite('lib');
    expect(
      await SiteDetacher().detachOrRemove(siteId: 'lib', ownerDiverId: 'd1'),
      isNull,
    );
    expect(await SharedLibraryStore().getSiteState('lib'), isNull);
  });

  test('a detached site keeps the documents attached to it', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(
        site: const DiveSite(id: 'lib', name: 'Club'),
      ),
    );
    final doc = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner(DocumentOwnerKind.site, 'lib'),
        type: DocumentType.permit,
        title: 'Briefing',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.txt',
          mimeType: 'text/plain',
          sizeBytes: 2,
          bytes: Uint8List.fromList([4, 2]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

    final newId = await SiteDetacher().detachOrRemove(
      siteId: 'lib',
      ownerDiverId: 'd1',
    );

    final kept = await DocumentRepository().getForOwner(
      DocumentOwner(DocumentOwnerKind.site, newId!),
    );
    expect(kept.map((d) => d.id), [doc.id]);
  });

  test(
    'two devices detaching the same site make the same personal copy',
    () async {
      Future<String?> detachOnThisDevice() async {
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(
            site: const DiveSite(id: 'lib', name: 'Club'),
          ),
        );
        return SiteDetacher().detachOrRemove(siteId: 'lib', ownerDiverId: 'd1');
      }

      // The phone (this test's database from setUp)...
      final onPhone = await detachOnThisDevice();
      await tearDownTestDatabase();

      // ...and the tablet, each receiving the same library tombstone.
      await setUpTestDatabase();
      await DiverRepository().createDiver(
        Diver(
          id: 'd1',
          name: 'Ann',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await SiteRepository().createSite(
        const DiveSite(
          id: 'lib',
          name: 'Club',
          hazards: 'h',
          sharedLibraryId: 'L',
        ),
      );
      final onTablet = await detachOnThisDevice();

      expect(onPhone, isNotNull);
      expect(
        onTablet,
        onPhone,
        reason: 'personal sync merges one row, not two',
      );
      expect(onPhone, isNot('lib'));
    },
  );

  test('a copy that already arrived from another device is reused', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(
        site: const DiveSite(id: 'lib', name: 'Club'),
      ),
    );
    // The phone detached first; its copy reached this device by personal
    // sync before this device's library sync saw the tombstone.
    await SiteRepository().createSite(
      DiveSite(id: detachedSiteId('lib'), diverId: 'd1', name: 'Club'),
    );

    final id = await SiteDetacher().detachOrRemove(
      siteId: 'lib',
      ownerDiverId: 'd1',
    );

    expect(id, detachedSiteId('lib'));
    expect((await DiveRepository().getDiveById('dv'))!.site?.id, id);
    expect(await SiteRepository().getSiteById('lib'), isNull);
  });
}
