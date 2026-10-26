import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';

/// The importer reports the sites it created, so logbook rules can run on
/// them after the import (#3513). A deselected site resolved to an existing
/// one is not new and is not listed.
void main() {
  setUp(() => serveFakeHost('api.open-meteo.com'));
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  const sites = [
    {'uddfId': 's1', 'name': 'Salt Pier', 'country': 'US', 'region': 'HI'},
    {'uddfId': 's2', 'name': 'Molasses Reef', 'country': 'US', 'region': 'FL'},
  ];

  test('siteIds lists every created site', () async {
    final diverId = await createTestDiver();
    const data = UddfImportResult(sites: sites);
    final result = await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final created = await SiteRepository().getAllSites(diverId: diverId);
    expect(result.siteIds.toSet(), {for (final s in created) s.id});
    expect(result.siteIds, hasLength(2));
  });

  test('a deselected site is not listed', () async {
    final diverId = await createTestDiver();
    const data = UddfImportResult(sites: sites);
    final result = await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(sites: {0}),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final created = await SiteRepository().getAllSites(diverId: diverId);
    expect(created.single.name, 'Salt Pier');
    expect(result.siteIds, [created.single.id]);
  });
}
