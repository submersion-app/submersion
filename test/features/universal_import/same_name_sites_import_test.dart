import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart';

import '../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../helpers/fake_hosts.dart';
import '../../helpers/test_database.dart';

/// A dives CSV carried all the way into the library (#4015).
void main() {
  setUp(() => serveFakeHost('api.open-meteo.com'));
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  const dahab = DiveSite(
    id: 's1',
    name: 'Blue Hole',
    city: 'Dahab',
    region: 'South Sinai',
    country: 'Egypt',
  );
  const belize = DiveSite(
    id: 's2',
    name: 'Blue Hole',
    city: 'Lighthouse Reef',
    region: 'Belize District',
    country: 'Belize',
  );

  Future<UddfImportResult> parsed(List<Dive> dives) async {
    final csv = CsvDivesWriter(CsvExportUnits.metric).write(dives);
    final payload = await const SubmersionDivesCsvParser().parse(
      Uint8List.fromList(utf8.encode(csv)),
    );
    return UddfImportResult(
      sites: payload.entitiesOf(ImportEntityType.sites),
      dives: payload.entitiesOf(ImportEntityType.dives),
    );
  }

  Future<Map<String?, String?>> countryByDiveName() async {
    final summaries = await DiveRepository().getAllDives();
    final dives = await Future.wait(
      summaries.map((d) => DiveRepository().getDiveById(d.id)),
    );
    return {for (final d in dives) d!.name: d.site?.country};
  }

  test('an empty library keeps each dive at its own Blue Hole', () async {
    final data = await parsed([
      Dive(
        id: 'd1',
        name: 'Sinai',
        dateTime: DateTime.utc(2026, 1, 1, 10),
        site: dahab,
      ),
      Dive(
        id: 'd2',
        name: 'Caribbean',
        dateTime: DateTime.utc(2026, 1, 2, 10),
        site: belize,
      ),
    ]);

    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final sites = await SiteRepository().getAllSites(diverId: diverId);
    expect(sites.map((s) => s.country), unorderedEquals(['Egypt', 'Belize']));
    expect(await countryByDiveName(), {
      'Sinai': 'Egypt',
      'Caribbean': 'Belize',
    });
  });

  test('a skipped site links its dive to the namesake in the same place, '
      'whichever the library lists last', () async {
    final data = await parsed([
      Dive(
        id: 'd1',
        name: 'Sinai',
        dateTime: DateTime.utc(2026, 1, 1, 10),
        site: dahab,
      ),
      Dive(
        id: 'd2',
        name: 'Caribbean',
        dateTime: DateTime.utc(2026, 1, 2, 10),
        site: belize,
      ),
    ]);

    final diverId = await createTestDiver();
    for (final site in const [dahab, belize]) {
      await SiteRepository().createSite(site.copyWith(diverId: diverId));
    }
    final all = UddfImportSelections.selectAll(data);
    final selections = UddfImportSelections(dives: all.dives);
    await UddfEntityImporter().import(
      data: data,
      selections: selections,
      repositories: buildRepositories(),
      diverId: diverId,
    );

    expect(await SiteRepository().getAllSites(diverId: diverId), hasLength(2));
    expect(await countryByDiveName(), {
      'Sinai': 'Egypt',
      'Caribbean': 'Belize',
    });
  });
}
