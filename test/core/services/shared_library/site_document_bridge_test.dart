import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SiteDocumentBridge bridge;

  setUp(() async {
    await setUpTestDatabase();
    bridge = SiteDocumentBridge();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Map<String, FieldClock> allClocks() => {
    for (final f in SiteDocument.fieldNames)
      f: const FieldClock(hlc: Hlc(1, 0, 'm'), memberId: 'm'),
  };

  test('apply creates a library row with children resolved by name', () async {
    final doc = SiteDocument(
      id: 's1',
      fields: {
        'name': 'Blue Hole',
        'latitude': 1.5,
        'longitude': 2.5,
        'maxDepth': 30.0,
        'hazards': 'current',
        'entryMethod': 'shore',
        'siteTypes': ['Reef'],
        'tags': ['Reef Survey'],
        'species': [
          {'name': 'Grouper', 'scientificName': 'Epinephelus'},
        ],
        'features': [
          {
            'id': 'f1',
            'type': 'mooring',
            'name': 'M1',
            'latitude': 1.0,
            'longitude': 2.0,
            'bearingDeg': null,
            'depthMeters': 5.0,
            'notes': '',
          },
        ],
      },
      clocks: allClocks(),
    );
    await bridge.apply(doc, libraryId: 'L', vocabularyDiverId: 'd1');

    final site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.sharedLibraryId, 'L');
    expect(site.diverId, isNull);
    expect(site.isShared, isFalse);
    expect(site.hazards, 'current');
    expect(site.maxDepth, 30.0);
    expect(site.location?.latitude, 1.5);
    expect(site.entryMethod?.name, 'shore');
    expect(
      (await SiteClassificationRepository().getTypesForSite(
        's1',
      )).map((t) => t.name),
      ['Reef'],
    );
    expect(
      (await SiteClassificationRepository().getTagsForSite(
        's1',
      )).map((t) => t.name),
      ['Reef Survey'],
    );
    final features = await SiteFeatureRepository().getFeaturesForSite('s1');
    expect(features.single.id, 'f1');
    expect(features.single.depthMeters, 5.0);
    final species = await SpeciesRepository().getExpectedSpeciesForSite('s1');
    expect(species.single.speciesName, 'Grouper');
    final tag = (await TagRepository().getAllTags(diverId: 'd1')).single;
    expect(tag.diverId, 'd1', reason: 'vocabulary belongs to the diver');
  });

  test('apply reuses existing vocabulary case-insensitively', () async {
    final doc = SiteDocument(
      id: 's1',
      fields: {
        'name': 'A',
        'siteTypes': ['reef'],
      },
      clocks: allClocks(),
    );
    await bridge.apply(doc, libraryId: 'L', vocabularyDiverId: 'd1');
    final types = await SiteClassificationRepository().getTypesForSite('s1');
    expect(types.single.isBuiltIn, isTrue, reason: 'the built-in Reef');
  });

  test('apply with a field subset leaves other columns alone', () async {
    await SiteRepository().createSite(
      const DiveSite(
        id: 's2',
        name: 'Old',
        notes: 'keep',
        sharedLibraryId: 'L',
      ),
    );
    const doc = SiteDocument(
      id: 's2',
      fields: {'name': 'New', 'notes': 'drop'},
    );
    await bridge.apply(
      doc,
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      fields: {'name'},
    );
    final site = (await SiteRepository().getSiteById('s2'))!;
    expect(site.name, 'New');
    expect(site.notes, 'keep');
  });

  test('apply replaces the feature list as a unit', () async {
    final first = SiteDocument(
      id: 's3',
      fields: {
        'name': 'S',
        'features': [
          {'id': 'f1', 'type': 'mooring', 'latitude': 1.0, 'longitude': 2.0},
          {'id': 'f2', 'type': 'wreck', 'latitude': 1.1, 'longitude': 2.1},
        ],
      },
      clocks: allClocks(),
    );
    await bridge.apply(first, libraryId: 'L', vocabularyDiverId: 'd1');
    final second = first.copyWith(
      fields: {
        ...first.fields,
        'features': [
          {
            'id': 'f2',
            'type': 'wreck',
            'name': 'Bow',
            'latitude': 1.1,
            'longitude': 2.1,
          },
        ],
      },
    );
    await bridge.apply(second, libraryId: 'L', vocabularyDiverId: 'd1');
    final features = await SiteFeatureRepository().getFeaturesForSite('s3');
    expect(features.map((f) => f.id), ['f2']);
    expect(features.single.name, 'Bow');
  });

  test('build reads the row, children and clocks', () async {
    await SiteRepository().createSite(
      const DiveSite(id: 's4', name: 'S', hazards: 'h', sharedLibraryId: 'L'),
    );
    await SiteFeatureRepository().addFeature(
      siteId: 's4',
      typeName: 'mooring',
      latitude: 3.0,
      longitude: 4.0,
      depthMeters: 12.0,
    );
    const state = SharedSiteState(
      siteId: 's4',
      libraryId: 'L',
      clocks: {'name': FieldClock(hlc: Hlc(2, 0, 'm'), memberId: 'm')},
    );
    final doc = await bridge.build('s4', state);
    expect(doc.id, 's4');
    expect(doc.fields['name'], 'S');
    expect(doc.fields['hazards'], 'h');
    expect(doc.fields['siteTypes'], isEmpty);
    expect((doc.fields['features'] as List).single['depthMeters'], 12.0);
    expect(doc.clocks['name']?.memberId, 'm');
    expect(doc.deleted, isFalse);
    expect(doc.fields.keys, containsAll(SiteDocument.fieldNames));
  });

  test('fieldValue encodes enums and location in document form', () {
    const site = DiveSite(id: 'x', name: 'n', location: GeoPoint(5.5, 6.5));
    expect(SiteDocumentBridge.fieldValue(site, 'latitude'), 5.5);
    expect(SiteDocumentBridge.fieldValue(site, 'longitude'), 6.5);
    expect(SiteDocumentBridge.fieldValue(site, 'difficulty'), isNull);
  });

  test('apply does not mark the site pending for personal sync', () async {
    const doc = SiteDocument(id: 's5', fields: {'name': 'N'});
    await bridge.apply(doc, libraryId: 'L', vocabularyDiverId: 'd1');
    final pending = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM sync_records WHERE id = 'diveSites_s5'")
        .get();
    expect(pending, isEmpty);
  });

  test('a library site keeps its own notes and rating', () async {
    await SiteRepository().createSite(
      const DiveSite(
        id: 'p1',
        name: 'A',
        notes: 'mine',
        rating: 4,
        sharedLibraryId: 'L',
      ),
    );
    final doc = await bridge.build(
      'p1',
      const SharedSiteState(siteId: 'p1', libraryId: 'L'),
    );
    expect(doc.fields.containsKey('notes'), isFalse);
    expect(doc.fields.containsKey('rating'), isFalse);
    await bridge.apply(
      doc.copyWith(fields: {...doc.fields, 'name': 'B'}),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      fields: {'name'},
    );
    final site = (await SiteRepository().getSiteById('p1'))!;
    expect(site.name, 'B');
    expect(site.notes, 'mine');
    expect(site.rating, 4);
  });
}
