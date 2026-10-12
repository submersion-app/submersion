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
}
