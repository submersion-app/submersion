import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
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
        libraryName: 'Club',
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
      LibraryEditStamper.changedFields(a, a.copyWith(hazards: 'y', notes: 'n')),
      {'hazards', 'notes'},
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

  test('a stamp under another member keeps attribution', () async {
    await LibraryEditStamper().stamp(
      's',
      {'notes'},
      actingDiverId: 'd1',
      asMemberId: 'reader-7',
    );
    final state = (await SharedLibraryStore().getSiteState('s'))!;
    expect(state.clocks['notes']!.memberId, 'reader-7');
    expect(state.lastEditorMemberId, 'reader-7');
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
}
