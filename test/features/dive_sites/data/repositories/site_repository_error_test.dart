import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('SiteRepository error handling', () {
    late SiteRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = SiteRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('all methods rethrow on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      const testSite = DiveSite(id: 'test-id', name: 'Test Site');

      await expectLater(repository.getAllSites(), throwsA(anything));
      await expectLater(repository.getSiteById('test-id'), throwsA(anything));
      await expectLater(repository.createSite(testSite), throwsA(anything));
      await expectLater(repository.updateSite(testSite), throwsA(anything));
      await expectLater(repository.deleteSite('test-id'), throwsA(anything));
      await expectLater(
        repository.getSitesByIds(['test-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.bulkDeleteSites(['test-id']),
        throwsA(anything),
      );
      await expectLater(repository.searchSites('test'), throwsA(anything));
      await expectLater(repository.getDiveCountsBySite(), throwsA(anything));
      await expectLater(repository.getSitesWithDiveCounts(), throwsA(anything));
      await expectLater(
        repository.mergeSites(mergedSite: testSite, siteIds: ['id-1', 'id-2']),
        throwsA(anything),
      );
    });
  });
}
