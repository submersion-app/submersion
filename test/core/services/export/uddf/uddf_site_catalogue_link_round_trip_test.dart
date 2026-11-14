import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// A site's link to the built-in catalogue record it was adopted from,
/// through a UDDF backup and restore. Nothing else in the file can rebuild
/// the link, so it travels as its own element. Restores go through the UDDF
/// parser the way the import wizard does.
void main() {
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

  test('a linked site keeps its link through a backup and restore', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(
        id: '',
        name: 'Salt Pier',
        diverId: diverId,
        catalogueId: 'osm_node_663869401',
      ),
    );
    final xml = await exportOf(site);

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final data = await parseLikeTheWizard(xml);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
    );

    final restored = (await SiteRepository().getAllSites()).single;
    expect(restored.name, 'Salt Pier');
    expect(restored.catalogueId, 'osm_node_663869401');
  });

  test('a site without a link writes no catalogueid element', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'My Reef', diverId: diverId),
    );

    final xml = await exportOf(site);

    expect(xml, isNot(contains('<catalogueid')));
  });

  group('importing over an existing site', () {
    Future<DiveSite> importOver({
      required String? existingLink,
      required String? fileLink,
    }) async {
      final diverId = await createTestDiver();
      final repository = SiteRepository();
      final exported = await repository.createSite(
        DiveSite(
          id: '',
          name: 'Salt Pier',
          diverId: diverId,
          catalogueId: fileLink,
        ),
      );
      final xml = await exportOf(exported);
      await repository.deleteSite(exported.id);
      final local = await repository.createSite(
        DiveSite(
          id: '',
          name: 'Salt Pier (mine)',
          diverId: diverId,
          catalogueId: existingLink,
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

    test('a site without a link takes the file\'s', () async {
      final site = await importOver(existingLink: null, fileLink: 'osm_node_1');

      expect(site.name, 'Salt Pier');
      expect(site.catalogueId, 'osm_node_1');
    });

    test('a site with a link keeps its own', () async {
      final site = await importOver(
        existingLink: 'osm_node_2',
        fileLink: 'osm_node_1',
      );

      expect(site.catalogueId, 'osm_node_2');
    });

    test('a file without a link leaves the site\'s alone', () async {
      final site = await importOver(existingLink: 'osm_node_2', fileLink: null);

      expect(site.catalogueId, 'osm_node_2');
    });
  });
}
