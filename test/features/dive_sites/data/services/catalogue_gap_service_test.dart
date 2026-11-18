import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

// About 111 m per 0.001 degree of latitude.
const _pier = GeoPoint(12.0835, -68.2826);
const _pier40m = GeoPoint(12.08386, -68.2826);
const _wreck = GeoPoint(27.8138, 33.9200);
const _wreck40m = GeoPoint(27.81416, 33.9200);
const _blueHole = GeoPoint(28.5722, 34.5370);

const _saltPier = CatalogueSite(
  id: 'osm_pier',
  name: 'Salt Pier',
  location: _pier,
  countryCode: 'BQ',
  country: 'Caribbean Netherlands',
  maxDepth: 15,
  typeIds: ['reef'],
  source: 'osm',
);
const _thistlegorm = CatalogueSite(
  id: 'ukho_1',
  name: 'SS Thistlegorm',
  location: _wreck,
  maxDepth: 32,
  description: 'Cargo ship, lost 1941',
  kind: CatalogueKind.register,
  source: 'ukho',
);
const _blueHoleEgypt = CatalogueSite(
  id: 'osm_bh',
  name: 'Blue Hole',
  location: _blueHole,
  countryCode: 'EG',
  country: 'Egypt',
  region: 'South Sinai',
  source: 'osm',
);

/// A stamper whose library sites are editable or not, as told.
class _Stamper extends LibraryEditStamper {
  _Stamper(this.editable);

  final bool editable;
  int mayEditCalls = 0;

  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async {
    mayEditCalls++;
    return editable;
  }

  @override
  Future<void> stamp(
    String siteId,
    Set<String> fields, {
    String? actingDiverId,
  }) async {}

  @override
  Future<void> keepCatalogue(
    String siteId, {
    required String? catalogueId,
    required SiteCatalogueAnswers answers,
    String? actingDiverId,
  }) async {}
}

void main() {
  late AppDatabase db;
  late SiteRepository sites;
  late FakeSiteCatalogue catalogue;
  final elevationAsked = <GeoPoint>[];

  /// How many bulk change-log actions were opened.
  var bulkRuns = 0;

  CatalogueGapService service({
    LibraryEditStamper? stamper,
    Future<double?> Function(GeoPoint point)? fetchElevation,
    Future<SeaAreaIndex?> Function()? loadSeas,
    String Function()? placeNameLanguage,
    SiteCatalogueFillRepository? fills,
  }) => CatalogueGapService(
    siteRepository: sites,
    catalogue: catalogue,
    classification: SiteClassificationRepository(),
    fills: fills ?? SiteCatalogueFillRepository(stamper: stamper),
    stamper: stamper,
    fetchElevation:
        fetchElevation ??
        (point) async {
          elevationAsked.add(point);
          return 0;
        },
    loadSeas: loadSeas,
    placeNameLanguage: placeNameLanguage,
    // The change log needs the app's own triggers; a pass-through scope
    // keeps this test about the service.
    runBulk: <T>(body) {
      bulkRuns++;
      return body();
    },
  );

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    catalogue = FakeSiteCatalogue(const [
      _saltPier,
      _thistlegorm,
      _blueHoleEgypt,
    ]);
    elevationAsked.clear();
    bulkRuns = 0;
    await seedDivers(db, ['d1', 'd2']);
  });

  tearDown(tearDownTestDatabase);

  Future<void> mine(
    String id,
    String name, {
    GeoPoint? at,
    String? link,
    String? country,
  }) => sites.createSite(
    DiveSite(
      id: id,
      diverId: 'd1',
      name: name,
      location: at,
      catalogueId: link,
      country: country,
    ),
  );

  Future<List<CataloguePair>> pairs() => service().findPairs(diverId: 'd1');

  group('finding pairs', () {
    test('each kind of pair is found', () async {
      await mine('sure', 'salt pier', at: _pier40m);
      await mine('nearby', 'Thistlegorm', at: _wreck40m);
      await mine('named', 'Blue Hole', country: 'Egypt');

      final found = {for (final p in await pairs()) p.site.id: p};

      expect(found['sure']!.kind, CataloguePairKind.sure);
      expect(found['sure']!.record.id, 'osm_pier');
      expect(found['nearby']!.kind, CataloguePairKind.nearby);
      expect(found['nearby']!.record.id, 'ukho_1');
      expect(found['named']!.kind, CataloguePairKind.named);
      expect(found['named']!.record.id, 'osm_bh');
      expect(found, hasLength(3));
    });

    test('a linked site whose record has more to give is found', () async {
      await mine('s1', 'Salt Pier', at: _pier, link: 'osm_pier');

      final pair = (await pairs()).single;

      expect(pair.kind, CataloguePairKind.linked);
      expect(
        pair.fields,
        containsAll([CatalogueGapField.depth, CatalogueGapField.siteTypes]),
      );
    });

    test(
      'a site far from every record and of no known name has no pair',
      () async {
        await mine('s1', 'My Secret Reef', at: const GeoPoint(1, 1));

        expect(await pairs(), isEmpty);
      },
    );

    test(
      'a record one of the diver\'s sites is linked to is not offered again',
      () async {
        await mine(
          'adopted',
          'Salt Pier',
          at: const GeoPoint(40, 10),
          link: 'osm_pier',
        );
        await mine('twin', 'Salt Pier', at: _pier40m);

        expect([for (final p in await pairs()) p.site.id], ['adopted']);
      },
    );

    test(
      "another diver's shared site is not paired, yet claims its record",
      () async {
        await sites.createSite(
          const DiveSite(
            id: 'theirs',
            diverId: 'd2',
            name: 'Salt Pier',
            location: GeoPoint(40, 10),
            isShared: true,
            catalogueId: 'osm_pier',
          ),
        );
        await mine('mine', 'Salt Pier', at: _pier40m);

        expect(await pairs(), isEmpty);
      },
    );

    test(
      'a library site is paired only when the profile may edit it',
      () async {
        await db.customStatement(
          'INSERT INTO shared_library_memberships (id, diver_id, library_id, '
          'member_id, display_name, library_name, backend_kind, created_at, '
          "updated_at) VALUES ('ms', 'd1', 'L', 'm', 'd1', 'Club', 's3', 1, 1)",
        );
        await sites.createSite(
          const DiveSite(
            id: 'club',
            name: 'Salt Pier',
            location: _pier40m,
            sharedLibraryId: 'L',
          ),
        );

        final editable = await service(
          stamper: _Stamper(true),
        ).findPairs(diverId: 'd1');
        final readOnly = await service(
          stamper: _Stamper(false),
        ).findPairs(diverId: 'd1');

        expect(editable.single.site.id, 'club');
        expect(readOnly, isEmpty);
      },
    );

    test('who may edit a library is asked once, not once per site', () async {
      await db.customStatement(
        'INSERT INTO shared_library_memberships (id, diver_id, library_id, '
        'member_id, display_name, library_name, backend_kind, created_at, '
        "updated_at) VALUES ('ms', 'd1', 'L', 'm', 'd1', 'Club', 's3', 1, 1)",
      );
      for (final id in ['a', 'b', 'c']) {
        await sites.createSite(
          DiveSite(
            id: id,
            name: 'Reef $id',
            location: const GeoPoint(1, 1),
            sharedLibraryId: 'L',
          ),
        );
      }
      final stamper = _Stamper(true);

      await service(stamper: stamper).findPairs(diverId: 'd1');

      expect(stamper.mayEditCalls, 1);
    });

    test('a search that has been superseded stops reading', () async {
      for (final id in ['a', 'b', 'c', 'd']) {
        await mine(id, 'Reef $id', at: _pier40m);
      }
      var asked = 0;

      final found = await service().findPairs(
        diverId: 'd1',
        // Superseded after the second site has been read.
        isCancelled: () => ++asked > 2,
      );

      expect(found, isEmpty);
      expect(catalogue.nearCalls, 2);
    });

    test('an empty catalogue gives no pairs and no error', () async {
      catalogue.sites = [];
      await mine('s1', 'Salt Pier', at: _pier);
      await mine('s2', 'Blue Hole');
      await mine('s3', 'Salt Pier', link: 'osm_pier');

      expect(await pairs(), isEmpty);
    });

    test('a diver with no sites asks the catalogue nothing', () async {
      expect(await pairs(), isEmpty);
      expect(
        catalogue.nearCalls + catalogue.namedManyCalls + catalogue.byIdCalls,
        0,
      );
    });

    test('a located or linked site costs one catalogue read', () async {
      await mine('a', 'Salt Pier', at: _pier);
      await mine(
        'c',
        'Salt Pier',
        at: const GeoPoint(40, 10),
        link: 'osm_pier',
      );

      await pairs();

      expect(catalogue.nearCalls, 1);
      expect(catalogue.byIdCalls, 1);
      expect(catalogue.namedManyCalls, 0);
    });

    test('sites with no position are all answered by one read', () async {
      await mine('a', 'Blue Hole', country: 'Egypt');
      await mine('b', 'Salt Pier');
      await mine('c', 'Somewhere Else');
      await mine('d', '   ');

      final found = {for (final p in await pairs()) p.site.id: p.record.id};

      expect(catalogue.namedManyCalls, 1);
      expect(catalogue.namesAsked.single, {
        'Blue Hole',
        'Salt Pier',
        'Somewhere Else',
      });
      expect(found, {'a': 'osm_bh', 'b': 'osm_pier'});
    });
  });

  group('applying', () {
    test('counts what was linked and what was filled', () async {
      await mine('sure', 'Salt Pier', at: _pier40m);
      await mine('linked', 'Thistlegorm', at: _wreck, link: 'ukho_1');
      final found = {for (final p in await pairs()) p.site.id: p};

      final result = await service().apply([
        CatalogueApplyRequest(found['sure']!, const {}),
        CatalogueApplyRequest(found['linked']!, found['linked']!.fields),
      ], diverId: 'd1');

      expect(result.linked, 1);
      expect(result.filled, 1);
      expect(result.notApplied, 0);
      expect((await sites.getSiteById('sure'))!.catalogueId, 'osm_pier');
      expect((await sites.getSiteById('sure'))!.maxDepth, isNull);
      expect((await sites.getSiteById('linked'))!.maxDepth, 32);
    });

    test('fields left out are remembered and not offered again', () async {
      await mine('s1', 'Salt Pier', at: _pier40m);
      final pair = (await pairs()).single;
      expect(pair.fields, contains(CatalogueGapField.depth));

      await service().apply([
        CatalogueApplyRequest(pair, {CatalogueGapField.siteTypes}),
      ], diverId: 'd1');

      final site = (await sites.getSiteById('s1'))!;
      expect(site.maxDepth, isNull);
      expect(site.catalogueAnswers.declined['osm_pier'], contains('depth'));
      expect(await pairs(), isEmpty);
    });

    test(
      'a pair that can no longer be applied is counted, the rest go on',
      () async {
        await mine('a', 'Salt Pier', at: _pier40m);
        await mine('b', 'Thistlegorm', at: _wreck40m);
        final found = {for (final p in await pairs()) p.site.id: p};
        // Another screen links a different site to the pier's record.
        await mine('thief', 'Pier', link: 'osm_pier');

        final result = await service().apply([
          CatalogueApplyRequest(found['a']!, found['a']!.fields),
          CatalogueApplyRequest(found['b']!, found['b']!.fields),
        ], diverId: 'd1');

        expect(result.notApplied, 1);
        expect(result.linked, 1);
        expect((await sites.getSiteById('a'))!.catalogueId, isNull);
        expect((await sites.getSiteById('b'))!.catalogueId, 'ukho_1');
      },
    );

    test('a record the catalogue has dropped since is not applied', () async {
      await mine('a', 'Salt Pier', at: _pier40m);
      final pair = (await pairs()).single;
      // A catalogue import lands while the comparison is open.
      catalogue.sites = [_thistlegorm, _blueHoleEgypt];

      final result = await service().apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');

      expect(result.notApplied, 1);
      expect(result.linked, 0);
      final site = (await sites.getSiteById('a'))!;
      expect(site.catalogueId, isNull);
      expect(site.maxDepth, isNull);
    });

    test('a record the catalogue has changed since is not applied', () async {
      await mine('a', 'Salt Pier', at: _pier40m);
      final pair = (await pairs()).single;
      // The diver was shown 15 m; the catalogue now says otherwise.
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_pier',
          name: 'Salt Pier',
          location: _pier,
          countryCode: 'BQ',
          country: 'Caribbean Netherlands',
          maxDepth: 21,
          typeIds: ['reef'],
          source: 'osm',
        ),
      ];

      final result = await service().apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');

      expect(result.notApplied, 1);
      final site = (await sites.getSiteById('a'))!;
      expect(site.catalogueId, isNull);
      expect(site.maxDepth, isNull);
      // The next search offers what the catalogue holds now.
      expect((await pairs()).single.record.maxDepth, 21);
    });

    test('a write that throws is counted and does not stop the next', () async {
      await mine('a', 'Salt Pier', at: _pier40m);
      await mine('b', 'Thistlegorm', at: _wreck40m);
      final found = {for (final p in await pairs()) p.site.id: p};

      final result = await service(fills: _ThrowsFor('a')).apply([
        CatalogueApplyRequest(found['a']!, found['a']!.fields),
        CatalogueApplyRequest(found['b']!, found['b']!.fields),
      ], diverId: 'd1');

      expect(result.notApplied, 1);
      expect(result.linked, 1);
      expect((await sites.getSiteById('b'))!.catalogueId, 'ukho_1');
    });

    test('the result does not wait for the altitude lookups', () async {
      await mine('s1', 'Blue Hole', country: 'Egypt');
      final pair = (await pairs()).single;
      final lookup = Completer<double?>();
      final gaps = service(fetchElevation: (_) => lookup.future);

      final result = await gaps.apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');

      // The write is done and reported while the lookup is still out.
      expect(result.linked, 1);
      expect((await sites.getSiteById('s1'))!.location, _blueHole);
      expect((await sites.getSiteById('s1'))!.altitude, isNull);

      lookup.complete(7);
      await gaps.altitudeFills;
      expect((await sites.getSiteById('s1'))!.altitude, 7);
    });

    group('one change-log action', () {
      test('is opened for a list of pairs', () async {
        await mine('a', 'Salt Pier', at: _pier40m);
        await mine('b', 'Thistlegorm', at: _wreck40m);
        final found = await pairs();

        await service().apply([
          for (final pair in found) CatalogueApplyRequest(pair, pair.fields),
        ], diverId: 'd1');

        expect(bulkRuns, 1);
      });

      test('is not opened for one pair on its own', () async {
        await mine('a', 'Salt Pier', at: _pier40m);
        final pair = (await pairs()).single;

        await service().apply([
          CatalogueApplyRequest(pair, pair.fields),
        ], diverId: 'd1');

        expect(bulkRuns, 0);
        expect((await sites.getSiteById('a'))!.catalogueId, 'osm_pier');
      });
    });

    test('a site given a position has its altitude looked up once', () async {
      await mine('s1', 'Blue Hole', country: 'Egypt');
      final pair = (await pairs()).single;

      final gaps = service(
        fetchElevation: (point) async {
          elevationAsked.add(point);
          return 12;
        },
      );
      await gaps.apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');
      await gaps.altitudeFills;

      final site = (await sites.getSiteById('s1'))!;
      expect(site.location, _blueHole);
      expect(site.altitude, 12);
      expect(elevationAsked, [_blueHole]);
    });

    test('a failing altitude lookup leaves the fill in place', () async {
      await mine('s1', 'Blue Hole', country: 'Egypt');
      final pair = (await pairs()).single;

      final gaps = service(
        fetchElevation: (_) async => throw StateError('offline'),
      );
      final result = await gaps.apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');
      // The failure stays inside the lookup: nothing is thrown later.
      await gaps.altitudeFills;

      expect(result.linked, 1);
      expect(result.notApplied, 0);
      expect((await sites.getSiteById('s1'))!.location, _blueHole);
    });

    test(
      'an altitude the diver typed while the lookup was out is kept',
      () async {
        await mine('s1', 'Blue Hole', country: 'Egypt');
        final pair = (await pairs()).single;
        final lookup = Completer<double?>();
        final gaps = service(fetchElevation: (_) => lookup.future);
        await gaps.apply([
          CatalogueApplyRequest(pair, pair.fields),
        ], diverId: 'd1');

        // The diver opens the site and enters its altitude themselves.
        await sites.updateSiteAltitude('s1', 1800);
        lookup.complete(7);
        await gaps.altitudeFills;

        expect((await sites.getSiteById('s1'))!.altitude, 1800);
      },
    );

    test('an altitude the diver typed is not looked up again', () async {
      await sites.createSite(
        const DiveSite(
          id: 's1',
          diverId: 'd1',
          name: 'Blue Hole',
          country: 'Egypt',
          altitude: 300,
        ),
      );
      final pair = (await pairs()).single;

      final gaps = service();
      await gaps.apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');
      await gaps.altitudeFills;

      expect((await sites.getSiteById('s1'))!.location, _blueHole);
      expect((await sites.getSiteById('s1'))!.altitude, 300);
      expect(elevationAsked, isEmpty);
    });

    test(
      'no altitude is asked for a site that kept its own position',
      () async {
        await mine('s1', 'Salt Pier', at: _pier40m);
        final pair = (await pairs()).single;

        final gaps = service();
        await gaps.apply([
          CatalogueApplyRequest(pair, pair.fields),
        ], diverId: 'd1');
        await gaps.altitudeFills;

        expect(elevationAsked, isEmpty);
      },
    );

    test("the sea is written in the diver's place-name language", () async {
      final seas = SeaAreaIndex.fromJson(<String, dynamic>{
        'areas': <dynamic>[
          <String, dynamic>{
            'name': 'Test Sea',
            'bbox': <dynamic>[0, 0, 10, 10],
            'area': 100.0,
            'polygons': <dynamic>[
              <String, dynamic>{
                'outer': <dynamic>[0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
              },
            ],
            'names': <String, dynamic>{'de': 'Testmeer'},
          },
        ],
      });
      catalogue.sites = const [
        CatalogueSite(
          id: 'r_sea',
          name: 'Shark Reef',
          location: GeoPoint(5, 5),
          bodyOfWater: 'Test Sea',
          source: 'osm',
        ),
      ];
      await mine('s1', 'Shark Reef', at: const GeoPoint(5, 5));
      final gaps = service(
        loadSeas: () async => seas,
        placeNameLanguage: () => 'de',
      );
      final pair = (await gaps.findPairs(diverId: 'd1')).single;

      await gaps.apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');

      expect((await sites.getSiteById('s1'))!.bodyOfWater, 'Testmeer');
    });

    test('nothing to apply is nothing done', () async {
      final result = await service().apply(const [], diverId: 'd1');

      expect(result.linked, 0);
      expect(result.filled, 0);
      expect(result.notApplied, 0);
    });
  });

  group('answers', () {
    test('"not the same site" takes the pair off the list for good', () async {
      await mine('s1', 'Thistlegorm', at: _wreck40m);
      final pair = (await pairs()).single;

      await service().answerNotSame(pair, diverId: 'd1');

      expect(await pairs(), isEmpty);
      expect((await sites.getSiteById('s1'))!.catalogueAnswers.notSame, {
        'ukho_1',
      });
      expect((await sites.getSiteById('s1'))!.catalogueId, isNull);
    });

    test('"no thanks" turns down every field on offer', () async {
      await mine('s1', 'Salt Pier', at: _pier, link: 'osm_pier');
      final pair = (await pairs()).single;

      await service().declineAll(pair, diverId: 'd1');

      expect(await pairs(), isEmpty);
      final site = (await sites.getSiteById('s1'))!;
      expect(site.maxDepth, isNull);
      expect(site.catalogueAnswers.declined['osm_pier'], {
        for (final field in pair.fields) field.name,
      });
    });
  });
}

/// A fill repository whose write fails for one site.
class _ThrowsFor extends SiteCatalogueFillRepository {
  _ThrowsFor(this.siteId);

  final String siteId;

  @override
  Future<CatalogueFillWrite> applyFill({
    required String siteId,
    required CatalogueSite record,
    required Set<CatalogueGapField> fields,
    Set<CatalogueGapField> declined = const {},
    String? bodyOfWater,
    String? actingDiverId,
    bool stampLibrary = true,
  }) {
    if (siteId == this.siteId) throw StateError('disk full');
    return super.applyFill(
      siteId: siteId,
      record: record,
      fields: fields,
      declined: declined,
      bodyOfWater: bodyOfWater,
      actingDiverId: actingDiverId,
      stampLibrary: stampLibrary,
    );
  }
}
