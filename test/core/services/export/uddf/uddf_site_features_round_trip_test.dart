import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Site features (issue #2200) through a UDDF backup and restore. Restores go
/// through the UDDF parser the way the import wizard does: its payload keeps
/// only entity lists plus metadata, so anything carried elsewhere would be
/// lost on a real import while a direct importer call still passed.
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
    return UddfImportResult(sites: payload.entitiesOf(ImportEntityType.sites));
  }

  /// [diverId] restores into a diver that already exists, which is how a
  /// second restore of the same file reaches a library that already holds
  /// the site.
  Future<void> restore(String xml, {String? diverId}) async {
    final restoredDiver = diverId ?? await createTestDiver();
    final data = await parseLikeTheWizard(xml);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: restoredDiver,
    );
  }

  test('a site feature survives a backup and restore', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Lake wreck', diverId: diverId),
    );
    final features = SiteFeatureRepository();
    final bow = await features.addFeature(
      siteId: site.id,
      typeName: 'wreck',
      name: 'Bow section',
      latitude: 36.123456,
      longitude: -5.654321,
      bearingDeg: 135,
      depthMeters: 18.5,
      notes: 'Swim-through at the break',
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
      siteFeaturesBySite: {
        site.id: [bow],
      },
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restore(xml);

    final restoredSite = (await SiteRepository().getAllSites()).single;
    final restored = await SiteFeatureRepository().getFeaturesForSite(
      restoredSite.id,
    );
    expect(restored, hasLength(1));
    final feature = restored.single;
    expect(feature.typeName, 'wreck');
    expect(feature.name, 'Bow section');
    expect(feature.latitude, closeTo(36.123456, 0.000001));
    expect(feature.longitude, closeTo(-5.654321, 0.000001));
    expect(feature.bearingDeg, closeTo(135, 0.001));
    expect(feature.depthMeters, closeTo(18.5, 0.001));
    expect(feature.notes, 'Swim-through at the break');
  });

  test('a feature type from a newer build round-trips verbatim', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Cavern', diverId: diverId),
    );
    // A type this build has no enum value for; the entity keeps the raw
    // name so the UI can fall back to a generic marker.
    final future = await SiteFeatureRepository().addFeature(
      siteId: site.id,
      typeName: 'thermocline',
      latitude: 1.5,
      longitude: 2.5,
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
      siteFeaturesBySite: {
        site.id: [future],
      },
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restore(xml);

    final restoredSite = (await SiteRepository().getAllSites()).single;
    final restored = await SiteFeatureRepository().getFeaturesForSite(
      restoredSite.id,
    );
    expect(restored.single.typeName, 'thermocline');
    expect(
      restored.single.type,
      isNull,
      reason: 'an unknown name stays unparsed rather than being coerced',
    );
  });

  test('restoring onto a site that already has the feature does not double '
      'it', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Lake wreck', diverId: diverId),
    );
    final mooring = await SiteFeatureRepository().addFeature(
      siteId: site.id,
      typeName: 'mooring',
      latitude: 36.123456,
      longitude: -5.654321,
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
      siteFeaturesBySite: {
        site.id: [mooring],
      },
    );

    // Restore into the same library, overwriting the site the wizard
    // matched rather than creating a second one: the features in the file
    // land on a site that already holds them.
    final data = await parseLikeTheWizard(xml);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections(siteOverrides: {0: site.id}),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final restored = await SiteFeatureRepository().getFeaturesForSite(site.id);
    expect(restored.map((f) => f.typeName), ['mooring']);
  });
  test('the dives-only export carries a site feature and its paired importer '
      'reads it back', () async {
    final diverId = await createTestDiver();
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Lake wreck', diverId: diverId),
    );
    final entry = await SiteFeatureRepository().addFeature(
      siteId: site.id,
      typeName: 'entry',
      name: 'Slipway',
      latitude: 36.1,
      longitude: -5.6,
      depthMeters: 2,
    );

    final xml = await UddfExportService().generateDivesUddfContent(
      const [],
      sites: [site],
      extras: UddfDivesExtras(
        siteFeaturesBySite: {
          site.id: [entry],
        },
      ),
    );

    final parsed = await UddfImportService().importDivesFromUddf(xml);
    final parsedSite = parsed['sites']!.single;
    final features = parsedSite['siteFeatures'] as List?;
    expect(features, isNotNull, reason: 'dives-only export writes features');
    expect(features, hasLength(1));
    expect(features!.single['typeName'], 'entry');
    expect(features.single['name'], 'Slipway');
    expect(features.single['depthMeters'], 2);
  });
}
