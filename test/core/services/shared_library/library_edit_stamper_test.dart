import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveSitesCompanion;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 's', name: 'S', sharedLibraryId: 'L'),
    );
  });

  tearDown(tearDownTestDatabase);

  test('changedFields names only the fields that differ', () {
    const a = DiveSite(id: 's', name: 'S', hazards: 'x');
    expect(
      LibraryEditStamper.changedFields(
        a,
        a.copyWith(hazards: 'y', parkingInfo: 'n', notes: 'private'),
      ),
      {'hazards', 'parkingInfo'},
    );
    expect(LibraryEditStamper.changedFields(a, a), isEmpty);
  });

  test(
    'updateSite on a library site stamps the changed fields and dirties the state',
    () async {
      final site = (await SiteRepository().getSiteById('s'))!;
      await SiteRepository().updateSite(
        site.copyWith(hazards: 'current'),
        actingDiverId: 'd1',
      );
      final state = (await SharedLibraryStore().getSiteState('s'))!;
      expect(state.dirty, isTrue);
      expect(state.clocks.keys, ['hazards']);
      expect(state.clocks['hazards']!.memberId, 'm1');
      expect(state.lastEditorMemberId, 'm1');
    },
  );

  for (final (role, writes) in [
    (SharedLibraryRole.reader, false),
    (SharedLibraryRole.editor, true),
  ]) {
    test('an imported altitude reaches a library site only for an editor '
        '(${role.name})', () async {
      await SharedLibraryStore().upsertLibrary(
        SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
          roles: SharedLibraryRoles(
            owners: const {'o'},
            editors: {if (role == SharedLibraryRole.editor) 'm1'},
          ),
        ),
      );
      await SiteRepository().updateSiteAltitude('s', 120);
      final site = (await SiteRepository().getSiteById('s'))!;
      expect(site.altitude, writes ? 120 : isNull);
      expect(
        (await SharedLibraryStore().getSiteState('s'))?.dirty ?? false,
        writes,
      );
    });
  }

  test(
    "a reader's import keeps the library's values, not their notes",
    () async {
      await SharedLibraryStore().upsertLibrary(
        const SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
          roles: SharedLibraryRoles(owners: {'o'}),
        ),
      );
      final site = (await SiteRepository().getSiteById('s'))!;
      await SiteRepository().updateSiteWithImportedMetadata(
        site.copyWith(name: 'Imported', notes: 'my own'),
        const DiveSitesCompanion(),
      );
      final after = (await SiteRepository().getSiteById('s'))!;
      expect(after.name, 'S');
      expect(after.notes, 'my own');
      expect(
        (await SharedLibraryStore().getSiteState('s'))?.dirty ?? false,
        isFalse,
      );
    },
  );

  test('a personal site is never stamped', () async {
    await SiteRepository().createSite(const DiveSite(id: 'p', name: 'P'));
    final site = (await SiteRepository().getSiteById('p'))!;
    await SiteRepository().updateSite(
      site.copyWith(notes: 'n'),
      actingDiverId: 'd1',
    );
    expect(await SharedLibraryStore().getSiteState('p'), isNull);
  });

  test('a later stamp of the same field replaces the clock', () async {
    final stamper = LibraryEditStamper();
    await stamper.stamp('s', {'name'}, actingDiverId: 'd1');
    final first = (await SharedLibraryStore().getSiteState(
      's',
    ))!.clocks['name']!;
    await stamper.stamp('s', {'name'}, actingDiverId: 'd1');
    final second = (await SharedLibraryStore().getSiteState(
      's',
    ))!.clocks['name']!;
    expect(second.hlc.compareTo(first.hlc), greaterThan(0));
  });

  test('type, feature and coordinate writes stamp their fields', () async {
    final types = await SiteTypeRepository().getAllSiteTypes(diverId: 'd1');
    await SiteClassificationRepository().replaceTypes('s', [types.first.id]);
    await SiteFeatureRepository().addFeature(
      siteId: 's',
      typeName: 'mooring',
      latitude: 1,
      longitude: 2,
    );
    await SiteRepository().updateSiteCoordinates('s', const GeoPoint(3.0, 4.0));
    final state = (await SharedLibraryStore().getSiteState('s'))!;
    expect(
      state.clocks.keys,
      containsAll(['siteTypes', 'features', 'latitude', 'longitude']),
    );
  });

  test(
    'without an acting diver the sole membership of the library is used',
    () async {
      await LibraryEditStamper().stamp('s', {'name'});
      final state = (await SharedLibraryStore().getSiteState('s'))!;
      expect(state.clocks['name']!.memberId, 'm1');
    },
  );

  test('a write that changes nothing stamps nothing', () async {
    final types = await SiteTypeRepository().getAllSiteTypes(diverId: 'd1');
    final classification = SiteClassificationRepository();
    await classification.replaceTypes('s', [types.first.id]);
    await SiteRepository().updateSiteCoordinates('s', const GeoPoint(3.0, 4.0));
    final before = (await SharedLibraryStore().getSiteState('s'))!;

    // A bulk action re-applying what the site already has.
    await classification.addTypes('s', [types.first.id]);
    await classification.replaceTypes('s', [types.first.id]);
    await classification.addTags('s', const []);
    await SiteRepository().updateSiteCoordinates('s', const GeoPoint(3.0, 4.0));

    final after = (await SharedLibraryStore().getSiteState('s'))!;
    expect(after.clocks, before.clocks);
  });

  test('a save from the edit page keeps the site in its library', () async {
    // The page builds the site without the library id and names the active
    // profile as owner; neither column may reach the row.
    await SiteRepository().updateSite(
      const DiveSite(id: 's', name: 'Renamed', diverId: 'd1'),
      actingDiverId: 'd1',
    );
    final row = (await SiteRepository().getSiteById('s'))!;
    expect(row.name, 'Renamed');
    expect(row.sharedLibraryId, 'L');
    expect(row.diverId, isNull);
    final state = (await SharedLibraryStore().getSiteState('s'))!;
    expect(state.clocks.keys, contains('name'));
  });

  test("a reader changes none of a library site's lists", () async {
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(owners: {'o'}),
      ),
    );
    final types = await SiteTypeRepository().getAllSiteTypes(diverId: 'd1');
    await SiteClassificationRepository().replaceTypes('s', [types.first.id]);
    await SiteClassificationRepository().addTypes('s', [types.first.id]);
    await expectLater(
      SiteFeatureRepository().addFeature(
        siteId: 's',
        typeName: 'mooring',
        latitude: 1,
        longitude: 2,
      ),
      throwsStateError,
    );
    expect(await SiteClassificationRepository().getTypesForSite('s'), isEmpty);
    expect(await SiteFeatureRepository().getFeaturesForSite('s'), isEmpty);
    expect(await SharedLibraryStore().getSiteState('s'), isNull);
  });

  test('an editor on a device holding writes edits as a reader', () async {
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(owners: {'o'}, editors: {'m1'}),
        rolesRejected: true,
      ),
    );
    await SiteRepository().updateSiteAltitude('s', 120);
    expect((await SiteRepository().getSiteById('s'))!.altitude, isNull);
    expect(await SharedLibraryStore().getSiteState('s'), isNull);
  });

  group('a device with an editor and a reader profile', () {
    setUp(() async {
      await DiverRepository().createDiver(
        Diver(
          id: 'd2',
          name: 'Bo',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await SharedLibraryStore().upsertMembership(
        const SharedLibraryMembership(
          id: 'ms2',
          diverId: 'd2',
          libraryId: 'L',
          memberId: 'm2',
          displayName: 'Bo',
          libraryName: 'Reef Survey',
          backendKind: 's3',
        ),
      );
      // Ann (m1) edits; Bo (m2) only reads.
      await SharedLibraryStore().upsertLibrary(
        const SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
          roles: SharedLibraryRoles(owners: {'o'}, editors: {'m1'}),
        ),
      );
    });

    test('a list change naming no profile is refused', () async {
      expect(await LibraryEditStamper().mayEdit('s'), isFalse);
      await SiteFeatureRepository().addFeature(
        siteId: 's',
        typeName: 'mooring',
        latitude: 1,
        longitude: 2,
        actingDiverId: 'd1',
      );
      final feature = (await SiteFeatureRepository().getFeaturesForSite(
        's',
      )).single;
      await SiteFeatureRepository().deleteFeature(feature.id);
      expect(
        await SiteFeatureRepository().getFeaturesForSite('s'),
        hasLength(1),
      );
    });

    test(
      "the reader's edits are refused, the editor's signed as theirs",
      () async {
        await expectLater(
          SiteFeatureRepository().addFeature(
            siteId: 's',
            typeName: 'mooring',
            latitude: 1,
            longitude: 2,
            actingDiverId: 'd2',
          ),
          throwsStateError,
        );
        final types = await SiteTypeRepository().getAllSiteTypes(diverId: 'd1');
        await SiteClassificationRepository().addTypes('s', [
          types.first.id,
        ], actingDiverId: 'd2');
        expect(
          await SiteClassificationRepository().getTypesForSite('s'),
          isEmpty,
        );
        await SiteClassificationRepository().addTypes('s', [
          types.first.id,
        ], actingDiverId: 'd1');
        final state = (await SharedLibraryStore().getSiteState('s'))!;
        expect(state.clocks['siteTypes']!.memberId, 'm1');
      },
    );

    test("replacing the reader's species list leaves it as it was", () async {
      final repository = SpeciesRepository();
      final species = [
        for (final name in ['Grouper', 'Turtle'])
          await repository.createSpecies(
            commonName: name,
            category: SpeciesCategory.other,
          ),
      ];
      await repository.addExpectedSpecies(
        siteId: 's',
        speciesId: species.first.id,
        actingDiverId: 'd1',
      );
      final reader = SiteExpectedSpeciesNotifier(
        repository,
        's',
        actingDiverId: () async => 'd2',
      );
      await reader.setSpecies([species.last.id]);
      final kept = await repository.getExpectedSpeciesForSite('s');
      expect(kept.map((e) => e.speciesId), [species.first.id]);
    });
  });
}
