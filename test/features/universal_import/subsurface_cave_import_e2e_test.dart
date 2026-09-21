import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

import '../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../helpers/test_database.dart';

/// A cave logbook from Subsurface, parsed and imported the way the wizard
/// does it, asserted where the diver sees it: on the stored dive and site
/// (issue #2202).
void main() {
  const fixturePath =
      'test/features/universal_import/data/parsers/fixtures/cave-tags.ssrf';

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<UddfImportResult> parseFixture() async {
    final payload = await SubsurfaceXmlParser().parse(
      Uint8List.fromList(await File(fixturePath).readAsBytes()),
    );
    // The mapping `UniversalAdapter` applies to a parser payload.
    return UddfImportResult(
      dives: payload.entitiesOf(ImportEntityType.dives),
      sites: payload.entitiesOf(ImportEntityType.sites),
      tags: payload.entitiesOf(ImportEntityType.tags),
    );
  }

  Future<void> importFixture(
    String diverId, {
    UddfImportSelections Function(UddfImportResult data)? selections,
  }) async {
    final data = await parseFixture();
    await UddfEntityImporter().import(
      data: data,
      selections:
          selections?.call(data) ?? UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
  }

  test('a cave logbook keeps its dive types through the import', () async {
    final diverId = await createTestDiver();
    await importFixture(diverId);

    final dives = await DiveRepository().getAllDives();
    final byNumber = {for (final d in dives) d.diveNumber: d};
    expect(dives, hasLength(4));
    expect(byNumber[1]!.diveTypeIds, ['cave']);
    expect(byNumber[2]!.diveTypeIds, ['cavern']);
    // Dive 3 is a deco dive: before the tags were read it would have been
    // classified 'technical' by the deco detector and nothing else.
    expect(byNumber[3]!.diveTypeIds, ['cave', 'deep']);
    expect(byNumber[4]!.diveTypeIds, ['boat', 'night']);
  });

  test('a cave logbook classifies the sites it dived', () async {
    final diverId = await createTestDiver();
    await importFixture(diverId);

    final sites = await SiteRepository().getAllSites();
    final classification = SiteClassificationRepository();
    Future<List<String>> typesOf(String name) async {
      final site = sites.firstWhere((s) => s.name == name);
      final types = await classification.getTypesForSite(site.id);
      return types.map((t) => t.id).toList();
    }

    expect(await typesOf('Dos Ojos'), ['cave']);
    expect(await typesOf('Chac Mool'), ['cavern']);
    expect(await typesOf('Escambron'), isEmpty);
  });

  test('a site the diver already classified is left alone', () async {
    final diverId = await createTestDiver();
    // The diver calls Dos Ojos a cenote. A cave-tagged dive landing on that
    // site must not overrule them: the tag only ever suggests.
    final mine = await SiteRepository().createSite(
      DiveSite(
        id: '',
        name: 'Dos Ojos',
        diverId: diverId,
        location: const GeoPoint(20.323100, -87.392400),
      ),
      classification: const SiteClassification(typeIds: ['cenote']),
    );

    // The wizard offers the duplicate as an overwrite, which is the path
    // that writes an import's classification onto a site the diver owns.
    await importFixture(
      diverId,
      selections: (data) {
        final dosOjos = data.sites.indexWhere((s) => s['name'] == 'Dos Ojos');
        final all = UddfImportSelections.selectAll(data);
        return UddfImportSelections(
          dives: all.dives,
          tags: all.tags,
          sites: {...all.sites}..remove(dosOjos),
          siteOverrides: {dosOjos: mine.id},
        );
      },
    );

    final types = await SiteClassificationRepository().getTypesForSite(mine.id);
    expect(types.map((t) => t.id), ['cenote']);
  });

  test('a site with no types of its own takes the suggestion', () async {
    final diverId = await createTestDiver();
    final mine = await SiteRepository().createSite(
      DiveSite(
        id: '',
        name: 'Dos Ojos',
        diverId: diverId,
        location: const GeoPoint(20.323100, -87.392400),
      ),
    );

    await importFixture(
      diverId,
      selections: (data) {
        final dosOjos = data.sites.indexWhere((s) => s['name'] == 'Dos Ojos');
        final all = UddfImportSelections.selectAll(data);
        return UddfImportSelections(
          dives: all.dives,
          tags: all.tags,
          sites: {...all.sites}..remove(dosOjos),
          siteOverrides: {dosOjos: mine.id},
        );
      },
    );

    final types = await SiteClassificationRepository().getTypesForSite(mine.id);
    expect(types.map((t) => t.id), ['cave']);
  });
}
