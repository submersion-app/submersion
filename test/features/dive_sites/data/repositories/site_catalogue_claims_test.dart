import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, SharedLibraryMembershipsCompanion, SiteHidesCompanion;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Which of a diver's sites claims a catalogue record: the one linked to
/// it, or one that stands for it because a merge folded its site away.
/// Adoption asks this before it creates a site.
void main() {
  late SiteRepository sites;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    await seedDivers(db, ['d1', 'd2']);
  });

  tearDown(tearDownTestDatabase);

  Future<void> joinLibrary(String diverId, String libraryId) => db
      .into(db.sharedLibraryMemberships)
      .insert(
        SharedLibraryMembershipsCompanion.insert(
          id: '$diverId:$libraryId',
          diverId: diverId,
          libraryId: libraryId,
          memberId: 'm-$diverId',
          displayName: diverId,
          libraryName: libraryId,
          backendKind: 's3',
          createdAt: kSharedTs,
          updatedAt: kSharedTs,
        ),
      );

  test('a site that stands for a record claims it', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        diverId: 'd1',
        name: 'Hilma Hooker',
        catalogueId: 'r1',
        catalogueAnswers: SiteCatalogueAnswers(also: {'r2'}),
      ),
    );

    expect((await sites.getSiteByCatalogueId('r2', diverId: 'd1'))!.id, 's1');
    expect(await sites.getSiteByCatalogueId('r2', diverId: 'd2'), isNull);
  });

  test(
    'the linked site wins over one that only stands for the record',
    () async {
      await sites.createSite(
        const DiveSite(
          id: 'standing',
          diverId: 'd1',
          name: 'A',
          catalogueAnswers: SiteCatalogueAnswers(also: {'r2'}),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await sites.createSite(
        const DiveSite(
          id: 'linked',
          diverId: 'd1',
          name: 'B',
          catalogueId: 'r2',
        ),
      );

      expect(
        (await sites.getSiteByCatalogueId('r2', diverId: 'd1'))!.id,
        'linked',
      );
    },
  );

  test('a record id is matched whole, never as part of another', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        diverId: 'd1',
        name: 'A',
        catalogueAnswers: SiteCatalogueAnswers(
          also: {'osm_node_12', 'osmXnodeX1', 'xosm_node_1'},
        ),
      ),
    );

    expect(
      await sites.getSiteByCatalogueId('osm_node_1', diverId: 'd1'),
      isNull,
    );
    expect(
      (await sites.getSiteByCatalogueId('osm_node_12', diverId: 'd1'))!.id,
      's1',
    );
  });

  test('a record a site said it is not does not claim it', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        diverId: 'd1',
        name: 'A',
        catalogueAnswers: SiteCatalogueAnswers(
          notSame: {'r2'},
          declined: {
            'r3': {'depth'},
          },
        ),
      ),
    );

    expect(await sites.getSiteByCatalogueId('r2', diverId: 'd1'), isNull);
    expect(await sites.getSiteByCatalogueId('r3', diverId: 'd1'), isNull);
  });

  test(
    "a library site's link counts for a member and for nobody else",
    () async {
      await joinLibrary('d1', 'lib1');
      await sites.createSite(
        const DiveSite(
          id: 'club',
          name: 'Club Wreck',
          sharedLibraryId: 'lib1',
          catalogueId: 'r1',
        ),
      );

      expect(
        (await sites.getSiteByCatalogueId('r1', diverId: 'd1'))!.id,
        'club',
      );
      expect(await sites.getSiteByCatalogueId('r1', diverId: 'd2'), isNull);
    },
  );

  test('a library site the diver has hidden claims nothing for them', () async {
    await joinLibrary('d1', 'lib1');
    await joinLibrary('d2', 'lib1');
    await sites.createSite(
      const DiveSite(
        id: 'club',
        name: 'Club Wreck',
        sharedLibraryId: 'lib1',
        catalogueId: 'r1',
        catalogueAnswers: SiteCatalogueAnswers(also: {'r2'}),
      ),
    );
    await db
        .into(db.siteHides)
        .insert(
          SiteHidesCompanion.insert(
            id: 'h1',
            siteId: 'club',
            diverId: 'd1',
            createdAt: kSharedTs,
          ),
        );

    expect(await sites.getSiteByCatalogueId('r1', diverId: 'd1'), isNull);
    expect(await sites.getSiteByCatalogueId('r2', diverId: 'd1'), isNull);
    // Another member, who has not hidden it, still sees it claimed.
    expect((await sites.getSiteByCatalogueId('r1', diverId: 'd2'))!.id, 'club');
  });

  test("a diver's own site wins over a library site", () async {
    await joinLibrary('d1', 'lib1');
    await sites.createSite(
      const DiveSite(
        id: 'club',
        name: 'Club Wreck',
        sharedLibraryId: 'lib1',
        catalogueId: 'r1',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await sites.createSite(
      const DiveSite(
        id: 'mine',
        diverId: 'd1',
        name: 'Wreck',
        catalogueId: 'r1',
      ),
    );

    expect((await sites.getSiteByCatalogueId('r1', diverId: 'd1'))!.id, 'mine');
  });
}
