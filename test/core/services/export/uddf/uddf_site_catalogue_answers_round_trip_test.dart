import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// What a diver settled about catalogue records for a site, through a UDDF
/// backup and restore. Like the link, nothing else in the file can rebuild
/// it, so it travels as its own element beside `catalogueid`.
void main() {
  const answers = SiteCatalogueAnswers(
    also: {'osm_node_2'},
    notSame: {'ukho_3'},
    declined: {
      'osm_node_1': {'depth', 'description'},
    },
  );

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<UddfImportResult> parseLikeTheWizard(String xml) async {
    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    return UddfImportResult(sites: payload.entitiesOf(ImportEntityType.sites));
  }

  Future<String> exportOf(DiveSite site) => UddfFullExportService()
      .generateAllDataXmlForTest(dives: const [], sites: [site]);

  Future<DiveSite> restore(String xml) async {
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final data = await parseLikeTheWizard(xml);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
    );
    return (await SiteRepository().getAllSites()).single;
  }

  test('a site keeps its answers through a backup and restore', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(
        id: '',
        name: 'Salt Pier',
        diverId: diverId,
        catalogueId: 'osm_node_1',
        catalogueAnswers: answers,
      ),
    );

    final restored = await restore(await exportOf(site));

    expect(restored.catalogueId, 'osm_node_1');
    expect(restored.catalogueAnswers, answers);
  });

  test('a site without answers writes no catalogueanswers element', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'My Reef', diverId: diverId),
    );

    expect(await exportOf(site), isNot(contains('<catalogueanswers')));
  });

  test('text in the file that cannot be read restores as no answers', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(
        id: '',
        name: 'Salt Pier',
        diverId: diverId,
        catalogueAnswers: answers,
      ),
    );
    final xml = (await exportOf(site)).replaceFirst(
      RegExp('<catalogueanswers>.*?</catalogueanswers>', dotAll: true),
      '<catalogueanswers>[1, 2</catalogueanswers>',
    );
    expect(xml, contains('[1, 2'));

    final restored = await restore(xml);

    expect(restored.name, 'Salt Pier');
    expect(restored.catalogueAnswers, SiteCatalogueAnswers.empty);
  });

  group('importing over an existing site', () {
    Future<DiveSite> importOver({
      required SiteCatalogueAnswers existing,
      required SiteCatalogueAnswers inFile,
    }) async {
      final diverId = await createTestDiver();
      final repository = SiteRepository();
      final exported = await repository.createSite(
        DiveSite(
          id: '',
          name: 'Salt Pier',
          diverId: diverId,
          catalogueAnswers: inFile,
        ),
      );
      final xml = await exportOf(exported);
      await repository.deleteSite(exported.id);
      final local = await repository.createSite(
        DiveSite(
          id: '',
          name: 'Salt Pier (mine)',
          diverId: diverId,
          catalogueAnswers: existing,
        ),
      );

      final data = await parseLikeTheWizard(xml);
      await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections(siteOverrides: {0: local.id}),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      return (await repository.getSiteById(local.id))!;
    }

    const mine = SiteCatalogueAnswers(notSame: {'mine'});

    test('a site without answers takes the file\'s', () async {
      final site = await importOver(
        existing: SiteCatalogueAnswers.empty,
        inFile: answers,
      );

      expect(site.catalogueAnswers, answers);
    });

    test('a site with answers keeps its own', () async {
      final site = await importOver(existing: mine, inFile: answers);

      expect(site.catalogueAnswers, mine);
    });

    test('a file without answers leaves the site\'s alone', () async {
      final site = await importOver(
        existing: mine,
        inFile: SiteCatalogueAnswers.empty,
      );

      expect(site.catalogueAnswers, mine);
    });
  });
}
