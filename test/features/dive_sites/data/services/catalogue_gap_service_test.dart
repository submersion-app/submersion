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

  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async =>
      editable;

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
    runBulk: <T>(body) => body(),
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
        catalogue.nearCalls + catalogue.namedCalls + catalogue.byIdCalls,
        0,
      );
    });

    test('each site costs one catalogue read', () async {
      await mine('a', 'Salt Pier', at: _pier);
      await mine('b', 'Blue Hole');
      await mine(
        'c',
        'Salt Pier',
        at: const GeoPoint(40, 10),
        link: 'osm_pier',
      );
      await mine('d', '   ');

      await pairs();

      expect(catalogue.nearCalls, 1);
      expect(catalogue.namedCalls, 1);
      expect(catalogue.byIdCalls, 1);
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

    test('a site given a position has its altitude looked up once', () async {
      await mine('s1', 'Blue Hole', country: 'Egypt');
      final pair = (await pairs()).single;

      await service(
        fetchElevation: (point) async {
          elevationAsked.add(point);
          return 12;
        },
      ).apply([CatalogueApplyRequest(pair, pair.fields)], diverId: 'd1');

      final site = (await sites.getSiteById('s1'))!;
      expect(site.location, _blueHole);
      expect(site.altitude, 12);
      expect(elevationAsked, [_blueHole]);
    });

    test('a failing altitude lookup leaves the fill in place', () async {
      await mine('s1', 'Blue Hole', country: 'Egypt');
      final pair = (await pairs()).single;

      final result = await service(
        fetchElevation: (_) async => throw StateError('offline'),
      ).apply([CatalogueApplyRequest(pair, pair.fields)], diverId: 'd1');

      expect(result.linked, 1);
      expect(result.notApplied, 0);
      expect((await sites.getSiteById('s1'))!.location, _blueHole);
    });

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

      await service().apply([
        CatalogueApplyRequest(pair, pair.fields),
      ], diverId: 'd1');

      expect((await sites.getSiteById('s1'))!.location, _blueHole);
      expect((await sites.getSiteById('s1'))!.altitude, 300);
      expect(elevationAsked, isEmpty);
    });

    test(
      'no altitude is asked for a site that kept its own position',
      () async {
        await mine('s1', 'Salt Pier', at: _pier40m);
        final pair = (await pairs()).single;

        await service().apply([
          CatalogueApplyRequest(pair, pair.fields),
        ], diverId: 'd1');

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
  }) {
    if (siteId == this.siteId) throw StateError('disk full');
    return super.applyFill(
      siteId: siteId,
      record: record,
      fields: fields,
      declined: declined,
      bodyOfWater: bodyOfWater,
      actingDiverId: actingDiverId,
    );
  }
}
