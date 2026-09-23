import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// The commit-time half of the shared location contract (#2232).
///
/// Every registered importer funnels its site maps through `_importSites`,
/// which used to drop a nameless one outright. That took the coordinates with
/// it and, because the site never reached `idMapping`, silently un-linked
/// every dive pointing at it. Naming the site here is what lets a parser
/// inherit the contract rather than remember it.
///
/// `country` and `region` are set on every site with coordinates so the
/// importer's best-effort reverse geocode is skipped.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<String> importData(UddfImportResult data) async {
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    return diverId;
  }

  test('a site with coordinates and no name keeps them under a coordinate '
      'name', () async {
    final diverId = await importData(
      const UddfImportResult(
        sites: [
          {
            'uddfId': 's1',
            'latitude': 20.2114,
            'longitude': -87.4654,
            'country': 'MX',
            'region': 'Quintana Roo',
          },
        ],
      ),
    );

    final site = (await SiteRepository().getAllSites(diverId: diverId)).single;
    expect(site.name, '20.211400, -87.465400');
    expect(site.location?.latitude, 20.2114);
    expect(site.location?.longitude, -87.4654);
  });

  test('a dive linked to a nameless site keeps the link', () async {
    await importData(
      UddfImportResult(
        sites: const [
          {
            'uddfId': 's1',
            'latitude': 20.2114,
            'longitude': -87.4654,
            'country': 'MX',
            'region': 'Quintana Roo',
          },
        ],
        dives: [
          {
            'dateTime': DateTime.utc(2025, 3, 15, 9, 5),
            'maxDepth': 20.0,
            'site': const {'uddfId': 's1'},
          },
        ],
      ),
    );

    final id = (await DiveRepository().getAllDives()).single.id;
    final dive = (await DiveRepository().getDiveById(id))!;
    expect(dive.site?.name, '20.211400, -87.465400');
  });

  test(
    'a site whose name is blank rather than absent is still named',
    () async {
      final diverId = await importData(
        const UddfImportResult(
          sites: [
            {
              'uddfId': 's1',
              'name': '  ',
              'latitude': 20.2114,
              'longitude': -87.4654,
              'country': 'MX',
              'region': 'Quintana Roo',
            },
          ],
        ),
      );

      final site = (await SiteRepository().getAllSites(
        diverId: diverId,
      )).single;
      expect(site.name, '20.211400, -87.465400');
    },
  );

  test('a site with neither a name nor coordinates is still dropped', () async {
    final diverId = await importData(
      const UddfImportResult(
        sites: [
          {'uddfId': 's1', 'country': 'MX'},
        ],
      ),
    );

    expect(await SiteRepository().getAllSites(diverId: diverId), isEmpty);
  });

  test('a nameless site at 0/0 is dropped rather than placed in the '
      'Atlantic', () async {
    final diverId = await importData(
      const UddfImportResult(
        sites: [
          {'uddfId': 's1', 'latitude': 0.0, 'longitude': 0.0},
        ],
      ),
    );

    expect(await SiteRepository().getAllSites(diverId: diverId), isEmpty);
  });

  test(
    'a whole-degree coordinate a parser emitted as int does not throw',
    () async {
      final diverId = await importData(
        const UddfImportResult(
          sites: [
            {
              'uddfId': 's1',
              'name': 'Reef',
              'latitude': 20,
              'longitude': -87,
              'country': 'MX',
              'region': 'Quintana Roo',
            },
          ],
        ),
      );

      final site = (await SiteRepository().getAllSites(
        diverId: diverId,
      )).single;
      expect(site.location?.latitude, 20.0);
      expect(site.location?.longitude, -87.0);
    },
  );

  test(
    'a dive carrying its own coordinates keeps them as its entry fix',
    () async {
      await importData(
        UddfImportResult(
          dives: [
            {
              'dateTime': DateTime.utc(2025, 3, 15, 9, 5),
              'maxDepth': 20.0,
              'latitude': 20.2114,
              'longitude': -87.4654,
            },
          ],
        ),
      );

      final id = (await DiveRepository().getAllDives()).single.id;
      final dive = (await DiveRepository().getDiveById(id))!;
      expect(dive.entryLocation?.latitude, 20.2114);
      expect(dive.entryLocation?.longitude, -87.4654);
    },
  );
}
