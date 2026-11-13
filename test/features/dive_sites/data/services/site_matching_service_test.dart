import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import 'site_matching_service_test.mocks.dart';

GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _diveAt(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

Dive _diveWithoutGps(String id) =>
    Dive(id: id, diveNumber: 1, dateTime: DateTime(2026, 1, 1), maxDepth: 18);

Dive _diveWithBareSite(String id, DiveSite site, {GeoPoint? gps}) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: gps,
  site: site,
);

const _bareSite = DiveSite(id: 'bare', name: 'Typed Twice');

@GenerateMocks([SiteRepository, DiveRepository, MediaRepository])
void main() {
  late MockSiteRepository sites;
  late FakeSiteCatalogue catalogue;
  late MockDiveRepository dives;
  late MockMediaRepository media;

  // Pass-through transaction runner so apply runs without a real database.
  SiteMatchingService service() => SiteMatchingService(
    siteRepository: sites,
    catalogue: catalogue,
    adoption: CatalogueAdoptionService(siteRepository: sites),
    diveRepository: dives,
    mediaRepository: media,
    diverId: 'diver-1',
    thresholds: SiteMatchSensitivity.balanced.thresholds,
    runInTransaction: (body) => body(),
  );

  setUp(() {
    sites = MockSiteRepository();
    // No catalogue site has been adopted yet, unless a test says so.
    when(
      sites.getSiteByCatalogueId(any, diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => null);
    catalogue = FakeSiteCatalogue();
    dives = MockDiveRepository();
    media = MockMediaRepository();
    when(media.getBestPhotoGpsForDives(any)).thenAnswer((_) async => const {});
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const []);
    when(dives.setSite(any, any)).thenAnswer((_) async {});
  });

  group('computeProposals', () {
    test('clear match: existing site within inner radius, no writes', () async {
      const existing = DiveSite(
        id: 's1',
        name: 'Blue Hole',
        location: GeoPoint(0, 0),
        maxDepth: 40,
        country: 'Egypt',
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => const [existing]);

      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(33)),
      ]);

      expect(proposals.single.status, ProposalStatus.clear);
      expect(proposals.single.recommendedCandidateId, 's1');
      final view = proposals.single.candidates.single;
      expect(view.name, 'Blue Hole');
      expect(view.maxDepth, 40);
      expect(view.location, const GeoPoint(0, 0));
      verifyNever(dives.setSite(any, any));
      verifyNever(
        sites.createSite(any, classification: anyNamed('classification')),
      );
    });

    test('no candidates -> none', () async {
      final proposals = await service().computeProposals([
        _diveAt('d1', const GeoPoint(10, 10)),
      ]);
      expect(proposals.single.status, ProposalStatus.none);
      expect(proposals.single.candidates, isEmpty);
    });

    test('two close sites -> review, no recommendation', () async {
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 'a', name: 'A', location: GeoPoint(0, 0.0003)),
          DiveSite(id: 'b', name: 'B', location: GeoPoint(0, 0.0006)),
        ],
      );
      final proposals = await service().computeProposals([
        _diveAt('d1', const GeoPoint(0, 0)),
      ]);
      expect(proposals.single.status, ProposalStatus.review);
      expect(proposals.single.recommendedCandidateId, isNull);
      expect(proposals.single.candidates.length, 2);
    });
  });

  group('catalogue candidates', () {
    test('an adopted site is not also offered as its catalogue twin', () async {
      // 400 m from the dive: outside the inner radius, so catalogue sites
      // compete, and the adopted site's own record would be a second card.
      final adopted = DiveSite(
        id: 's-adopted',
        name: 'Salt Pier',
        location: _eastMeters(400),
        catalogueId: 'osm_3',
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => [adopted]);
      catalogue.sites = [
        CatalogueSite(
          id: 'osm_3',
          name: 'Salt Pier',
          location: _eastMeters(400),
          source: 'osm',
        ),
      ];

      final proposals = await service().computeProposals([
        _diveAt('d1', const GeoPoint(0, 0)),
      ]);

      expect(proposals.single.candidates.map((c) => c.id), ['s-adopted']);
    });

    test('a card reads in words, not ids', () async {
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_4',
          name: 'The Tugs',
          location: GeoPoint(0, 0),
          typeIds: ['artificial_reef', 'wreck'],
          features: ['sharks'],
          difficulty: SiteDifficulty.beginner,
          source: 'osm',
        ),
      ];

      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(22)),
      ]);

      final card = proposals.single.candidates.single;
      expect(card.difficulty, 'Beginner');
      expect(card.features, ['Artificial reef', 'Wreck', 'sharks']);
    });
  });

  group('applyConfirmed', () {
    setUp(() {
      when(
        sites.createSite(any, classification: anyNamed('classification')),
      ).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-${s.name}');
      });
    });

    test('links an existing candidate; no site created', () async {
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
        ],
      );
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(33))]);

      final result = await s.applyConfirmed([const ConfirmedMatch('d1', 's1')]);

      expect(result.divesLinked, 1);
      expect(result.sitesCreated, 0);
      verify(dives.setSite('d1', 's1')).called(1);
      verifyNever(
        sites.createSite(any, classification: anyNamed('classification')),
      );
    });

    test(
      'materialises a bundled site once for two dives (batch dedup)',
      () async {
        catalogue.sites = const [
          CatalogueSite(
            id: 'osm_1',
            name: 'Wreck',
            location: GeoPoint(0, 0),
            source: 'osm',
          ),
        ];
        final s = service();
        await s.computeProposals([
          _diveAt('d1', _eastMeters(22)),
          _diveAt('d2', _eastMeters(33)),
        ]);

        final result = await s.applyConfirmed([
          const ConfirmedMatch('d1', 'osm_1'),
          const ConfirmedMatch('d2', 'osm_1'),
        ]);

        expect(result.divesLinked, 2);
        expect(result.sitesCreated, 1);
        // Logbook rules run on the sites a match created (#3513).
        expect(result.createdSiteIds, ['new-Wreck']);
        verify(
          sites.createSite(any, classification: anyNamed('classification')),
        ).called(1);
        verify(dives.setSite('d1', 'new-Wreck')).called(1);
        verify(dives.setSite('d2', 'new-Wreck')).called(1);
      },
    );

    test(
      'a materialised bundled site carries its mapped site types (#1765)',
      () async {
        catalogue.sites = const [
          CatalogueSite(
            id: 'osm_2',
            name: 'Lake wreck',
            location: GeoPoint(0, 0),
            typeIds: ['wreck', 'lake'],
            features: ['sharks'],
            source: 'osm',
          ),
        ];
        final s = service();
        await s.computeProposals([_diveAt('d1', _eastMeters(22))]);

        await s.applyConfirmed([const ConfirmedMatch('d1', 'osm_2')]);

        final captured = verify(
          sites.createSite(
            any,
            classification: captureAnyNamed('classification'),
          ),
        ).captured;
        expect((captured.single as SiteClassification).typeIds, [
          'wreck',
          'lake',
        ]);
      },
    );

    test(
      'coincidence guard links existing instead of creating bundled',
      () async {
        final existing = DiveSite(
          id: 's-exist',
          name: 'Known Reef',
          location: _eastMeters(160),
        );
        when(
          sites.getAllSites(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => [existing]);
        catalogue.sites = [
          CatalogueSite(
            id: 'osm_2',
            name: 'Reef',
            location: GeoPoint(0, _eastMeters(140).longitude),
            source: 'osm',
          ),
        ];
        final s = service();
        await s.computeProposals([_diveAt('d1', const GeoPoint(0, 0))]);

        final result = await s.applyConfirmed([
          const ConfirmedMatch('d1', 'osm_2'),
        ]);

        expect(result.sitesCreated, 0);
        verify(dives.setSite('d1', 's-exist')).called(1);
        verifyNever(
          sites.createSite(any, classification: anyNamed('classification')),
        );
      },
    );

    test('a created site carries the catalogue\'s details and link', () async {
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_3',
          name: 'Salt Pier',
          location: GeoPoint(0, 0),
          countryCode: 'BQ',
          country: 'Caribbean Netherlands',
          minDepth: 5,
          maxDepth: 15,
          typeIds: ['reef'],
          entryMethods: [EntryMethod.shore],
          description: 'Pillars.',
          source: 'osm',
        ),
      ];
      final s = service();
      final proposals = await s.computeProposals([
        _diveAt('d1', _eastMeters(22)),
      ]);
      // The review card shows the depth range the catalogue holds.
      expect(proposals.single.candidates.single.minDepth, 5);
      expect(proposals.single.candidates.single.maxDepth, 15);

      await s.applyConfirmed([const ConfirmedMatch('d1', 'osm_3')]);

      final captured = verify(
        sites.createSite(
          captureAny,
          classification: captureAnyNamed('classification'),
        ),
      ).captured;
      final created = captured[0] as DiveSite;
      expect(created.catalogueId, 'osm_3');
      expect(created.diverId, 'diver-1');
      expect(created.maxDepth, 15);
      expect(created.countryCode, 'BQ');
      expect(created.entryMethods, [EntryMethod.shore]);
      expect(created.description, 'Pillars.');
      // No "Imported from ..." boilerplate in the diver's own notes.
      expect(created.notes, '');
      expect((captured[1] as SiteClassification).typeIds, ['reef']);
    });

    test('a candidate adopted since the proposals were made is linked, not '
        'created again', () async {
      // Not among the diver's sites when the proposals were computed (it
      // was adopted on the map a moment later, or it has no coordinates
      // of its own any more), so its record was offered.
      const adopted = DiveSite(
        id: 's-adopted',
        name: 'Salt Pier',
        catalogueId: 'osm_3',
      );
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_3',
          name: 'Salt Pier',
          location: GeoPoint(0, 0),
          source: 'osm',
        ),
      ];
      final s = service();
      await s.computeProposals([_diveAt('d1', const GeoPoint(0, 0))]);
      when(
        sites.getSiteByCatalogueId('osm_3', diverId: 'diver-1'),
      ).thenAnswer((_) async => adopted);

      final result = await s.applyConfirmed([
        const ConfirmedMatch('d1', 'osm_3'),
      ]);

      expect(result.sitesCreated, 0);
      verify(dives.setSite('d1', 's-adopted')).called(1);
      verifyNever(
        sites.createSite(any, classification: anyNamed('classification')),
      );
    });

    test('empty confirmed list writes nothing', () async {
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(33))]);
      final result = await s.applyConfirmed(const []);
      expect(result.divesLinked, 0);
      verifyNever(dives.setSite(any, any));
    });
  });

  group('photo point source', () {
    test('falls back to the photo fix when the dive has no GPS', () async {
      const existing = DiveSite(
        id: 's1',
        name: 'Blue Hole',
        location: GeoPoint(0, 0),
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => const [existing]);
      when(media.getBestPhotoGpsForDives(['d1'])).thenAnswer(
        (_) async => {
          'd1': (
            mediaId: 'm1',
            location: _eastMeters(33),
            takenAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );

      final proposals = await service().computeProposals([
        _diveWithoutGps('d1'),
      ]);

      expect(proposals.single.status, ProposalStatus.clear);
      expect(proposals.single.recommendedCandidateId, 's1');
      expect(proposals.single.pointSource, PointSource.photo);
      expect(proposals.single.point, _eastMeters(33));
    });

    test('dive-computer GPS wins over a photo fix', () async {
      when(media.getBestPhotoGpsForDives(['d1'])).thenAnswer(
        (_) async => {
          'd1': (
            mediaId: 'm1',
            location: const GeoPoint(10, 10),
            takenAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );
      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(33)),
      ]);
      expect(proposals.single.pointSource, PointSource.diveComputer);
      expect(proposals.single.point, _eastMeters(33));
    });

    test('a dive with neither point is skipped', () async {
      final proposals = await service().computeProposals([
        _diveWithoutGps('d1'),
      ]);
      expect(proposals, isEmpty);
    });

    test('a failing photo query degrades to no photo point', () async {
      when(
        media.getBestPhotoGpsForDives(any),
      ).thenAnswer((_) async => throw StateError('db'));
      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(33)),
        _diveWithoutGps('d2'),
      ]);
      expect(proposals.map((p) => p.dive.id), ['d1']);
    });
  });

  group('current site without coordinates', () {
    setUp(() {
      when(
        sites.updateSiteCoordinates(any, any, altitude: anyNamed('altitude')),
      ).thenAnswer((_) async {});
      when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});
    });

    SiteMatchingService withElevation(Future<double?> Function(GeoPoint) f) =>
        SiteMatchingService(
          siteRepository: sites,
          catalogue: catalogue,
          adoption: CatalogueAdoptionService(siteRepository: sites),
          diveRepository: dives,
          mediaRepository: media,
          diverId: 'diver-1',
          thresholds: SiteMatchSensitivity.balanced.thresholds,
          runInTransaction: (body) => body(),
          fetchElevation: f,
        );

    test(
      'is the clear recommendation when no located site is nearby',
      () async {
        final proposals = await service().computeProposals([
          _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
        ]);
        final p = proposals.single;
        expect(p.status, ProposalStatus.clear);
        expect(p.recommendedCandidateId, 'current:bare');
        expect(p.candidates.first.isCurrentSite, isTrue);
        expect(p.candidates.first.name, 'Typed Twice');
      },
    );

    test(
      'goes to review when a located user site is within the inner radius',
      () async {
        const neighbour = DiveSite(
          id: 's1',
          name: 'Blue Hole',
          location: GeoPoint(0, 0),
        );
        when(
          sites.getAllSites(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => const [neighbour]);
        final proposals = await service().computeProposals([
          _diveWithBareSite('d1', _bareSite, gps: _eastMeters(40)),
        ]);
        final p = proposals.single;
        expect(p.status, ProposalStatus.review);
        expect(p.candidates.map((c) => c.id), ['current:bare', 's1']);
      },
    );

    test(
      'applying the current-site candidate patches coordinates only',
      () async {
        final s = service();
        await s.computeProposals([
          _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
        ]);
        final result = await s.applyConfirmed([
          const ConfirmedMatch('d1', 'current:bare'),
        ]);
        expect(result.sitesLocated, 1);
        expect(result.divesLinked, 1);
        verify(sites.updateSiteCoordinates('bare', _eastMeters(0))).called(1);
        verifyNever(sites.updateSite(any));
        verifyNever(dives.setSite(any, any));
      },
    );

    test(
      'the altitude pass runs after apply for sites that gained coordinates',
      () async {
        final s = withElevation((_) async => 12.0);
        await s.computeProposals([
          _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
        ]);
        await s.applyConfirmed([const ConfirmedMatch('d1', 'current:bare')]);
        verify(sites.updateSiteAltitude('bare', 12.0)).called(1);
      },
    );

    test('an elevation failure does not fail the apply', () async {
      final s = withElevation((_) async => throw StateError('offline'));
      await s.computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(0)),
      ]);
      final result = await s.applyConfirmed([
        const ConfirmedMatch('d1', 'current:bare'),
      ]);
      expect(result.sitesLocated, 1);
      verifyNever(sites.updateSiteAltitude(any, any));
    });
  });

  group('createAndLink', () {
    setUp(() {
      when(
        sites.createSite(any, classification: anyNamed('classification')),
      ).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-${s.name}');
      });
      when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});
    });

    test(
      'creates the site under the diver, links the dive, fills altitude',
      () async {
        final s = SiteMatchingService(
          siteRepository: sites,
          catalogue: catalogue,
          adoption: CatalogueAdoptionService(siteRepository: sites),
          diveRepository: dives,
          mediaRepository: media,
          diverId: 'diver-1',
          thresholds: SiteMatchSensitivity.balanced.thresholds,
          runInTransaction: (body) => body(),
          fetchElevation: (_) async => 3.0,
        );
        final created = await s.createAndLink(
          'd1',
          const DiveSite(id: 'x', name: 'Wall', location: GeoPoint(1, 2)),
        );
        expect(created.id, 'new-Wall');
        final saved =
            verify(sites.createSite(captureAny)).captured.single as DiveSite;
        expect(saved.diverId, 'diver-1');
        verify(dives.setSite('d1', 'new-Wall')).called(1);
        verify(sites.updateSiteAltitude('new-Wall', 3.0)).called(1);
      },
    );
  });
}
