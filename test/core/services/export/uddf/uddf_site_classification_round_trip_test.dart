import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Site types, site tags and tag scope through a UDDF backup and restore
/// (issue #1765). Restores go through the UDDF parser the way the import
/// wizard does: its payload keeps only entity lists plus metadata, so
/// anything carried elsewhere would be lost.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  /// The result the wizard rebuilds from a parsed payload (mirrors
  /// UniversalAdapter._payloadToUddfResult for the parts this test uses).
  Future<UddfImportResult> parseLikeTheWizard(String xml) async {
    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    return UddfImportResult(
      sites: payload.entitiesOf(ImportEntityType.sites),
      tags: payload.entitiesOf(ImportEntityType.tags),
      customSiteTypes: [
        for (final type
            in (payload.metadata[ImportPayload.customSiteTypesKey] as List?) ??
                const [])
          if (type is Map<String, dynamic>) type,
      ],
    );
  }

  test(
    'site types, site tags and tag scope survive a backup and restore',
    () async {
      final diverId = await createTestDiver();
      final mine = await SiteTypeRepository().createSiteType(
        SiteTypeEntity.create(id: 'mine', name: 'Mine', diverId: diverId),
      );
      final toTry = await TagRepository().getOrCreateTag(
        'To try',
        diverId: diverId,
        colorHex: '#EF4444',
        scope: TagScope.sites,
      );
      final site = await SiteRepository().createSite(
        DiveSite(id: '', name: 'Lake wreck', diverId: diverId),
        classification: SiteClassification(
          typeIds: ['wreck', mine.id],
          tagIds: [toTry.id],
        ),
      );

      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: const [],
        sites: [site],
        tags: [toTry],
        customSiteTypes: [mine],
        siteTypeIdsBySite: {
          site.id: ['wreck', mine.id],
        },
        siteTagIdsBySite: {
          site.id: [toTry.id],
        },
      );

      await tearDownTestDatabase();
      await setUpTestDatabase();
      final restoredDiver = await createTestDiver();
      final data = await parseLikeTheWizard(xml);
      await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: restoredDiver,
      );

      final restored = (await SiteRepository().getAllSites()).single;
      final classification = SiteClassificationRepository();
      final types = await classification.getTypesForSite(restored.id);
      expect(types.map((t) => t.name), ['Wreck', 'Mine']);
      expect(types.first.isBuiltIn, isTrue);
      expect(types.last.isBuiltIn, isFalse);

      final tags = await classification.getTagsForSite(restored.id);
      expect(tags.single.name, 'To try');
      expect(tags.single.appliesToSites, isTrue);
      expect(tags.single.appliesToDives, isFalse);
      expect(tags.single.colorHex, '#EF4444', reason: 'tag color on import');
    },
  );

  test('re-importing onto an existing site unions, never removes', () async {
    final diverId = await createTestDiver();
    final exported = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Quarry wall', diverId: diverId),
      classification: const SiteClassification(typeIds: ['lake']),
    );
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [exported],
      siteTypeIdsBySite: {
        exported.id: ['lake'],
      },
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final localDiver = await createTestDiver();
    final local = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Quarry wall', diverId: localDiver),
      classification: const SiteClassification(typeIds: ['wreck']),
    );

    await UddfEntityImporter().import(
      data: await parseLikeTheWizard(xml),
      // Site 0 of the file overwrites the existing local site.
      selections: UddfImportSelections(siteOverrides: {0: local.id}),
      repositories: buildRepositories(),
      diverId: localDiver,
    );

    final types = await SiteClassificationRepository().getTypesForSite(
      local.id,
    );
    expect(types.map((t) => t.id).toSet(), {'wreck', 'lake'});
  });

  group('suggested site types (Shearwater Environment)', () {
    Map<String, dynamic> siteMap(String name) => {
      'uddfId': name,
      'name': name,
      'suggestedSiteTypeRefs': ['quarry'],
    };

    test('apply to a site the import creates', () async {
      final diverId = await createTestDiver();
      final data = UddfImportResult(sites: [siteMap('Dutch Springs')]);
      await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      final site = (await SiteRepository().getAllSites()).single;
      final types = await SiteClassificationRepository().getTypesForSite(
        site.id,
      );
      expect(types.map((t) => t.id), ['quarry']);
    });

    test('never override the types a matched site already has', () async {
      final diverId = await createTestDiver();
      final local = await SiteRepository().createSite(
        DiveSite(id: '', name: 'Dutch Springs', diverId: diverId),
        classification: const SiteClassification(typeIds: ['lake']),
      );

      await UddfEntityImporter().import(
        data: UddfImportResult(sites: [siteMap('Dutch Springs')]),
        selections: UddfImportSelections(siteOverrides: {0: local.id}),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      final types = await SiteClassificationRepository().getTypesForSite(
        local.id,
      );
      expect(types.map((t) => t.id), ['lake']);
    });
  });

  test('a re-imported custom type reuses the existing one by name', () async {
    final diverId = await createTestDiver();
    final mine = await SiteTypeRepository().createSiteType(
      SiteTypeEntity.create(id: 'mine', name: 'Mine', diverId: diverId),
    );
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Old mine', diverId: diverId),
      classification: SiteClassification(typeIds: [mine.id]),
    );
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
      customSiteTypes: [mine],
      siteTypeIdsBySite: {
        site.id: [mine.id],
      },
    );

    // Same database: the custom type already exists under that name.
    final data = await parseLikeTheWizard(xml);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final custom = [
      for (final t in await SiteTypeRepository().getAllSiteTypes(
        diverId: diverId,
      ))
        if (!t.isBuiltIn) t,
    ];
    expect(custom.map((t) => t.name), ['Mine']);
  });
}
