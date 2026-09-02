import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

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

@GenerateMocks([
  SiteRepository,
  DiveSiteApiService,
  DiveRepository,
  MediaRepository,
])
void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;
  late MockMediaRepository media;

  // Pass-through transaction runner so apply runs without a real database.
  SiteMatchingService service() => SiteMatchingService(
    siteRepository: sites,
    apiService: api,
    diveRepository: dives,
    mediaRepository: media,
    diverId: 'diver-1',
    thresholds: SiteMatchSensitivity.balanced.thresholds,
    runInTransaction: (body) => body(),
  );

  setUp(() {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    media = MockMediaRepository();
    when(media.getBestPhotoGpsForDives(any)).thenAnswer((_) async => const {});
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));
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
      verifyNever(sites.createSite(any));
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

  group('applyConfirmed', () {
    setUp(() {
      when(sites.createSite(any)).thenAnswer((inv) async {
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
      verifyNever(sites.createSite(any));
    });

    test(
      'materialises a bundled site once for two dives (batch dedup)',
      () async {
        when(
          api.searchNearby(
            latitude: anyNamed('latitude'),
            longitude: anyNamed('longitude'),
            radiusKm: anyNamed('radiusKm'),
          ),
        ).thenAnswer(
          (_) async => const DiveSiteSearchResult(
            sites: [
              ExternalDiveSite(
                externalId: 'osm_1',
                name: 'Wreck',
                latitude: 0,
                longitude: 0,
                source: 'OpenStreetMap',
              ),
            ],
          ),
        );
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
        verify(sites.createSite(any)).called(1);
        verify(dives.setSite('d1', 'new-Wreck')).called(1);
        verify(dives.setSite('d2', 'new-Wreck')).called(1);
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
        when(
          api.searchNearby(
            latitude: anyNamed('latitude'),
            longitude: anyNamed('longitude'),
            radiusKm: anyNamed('radiusKm'),
          ),
        ).thenAnswer(
          (_) async => DiveSiteSearchResult(
            sites: [
              ExternalDiveSite(
                externalId: 'osm_2',
                name: 'Reef',
                latitude: 0,
                longitude: _eastMeters(140).longitude,
                source: 'OpenStreetMap',
              ),
            ],
          ),
        );
        final s = service();
        await s.computeProposals([_diveAt('d1', const GeoPoint(0, 0))]);

        final result = await s.applyConfirmed([
          const ConfirmedMatch('d1', 'osm_2'),
        ]);

        expect(result.sitesCreated, 0);
        verify(dives.setSite('d1', 's-exist')).called(1);
        verifyNever(sites.createSite(any));
      },
    );

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
          apiService: api,
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
      when(sites.createSite(any)).thenAnswer((inv) async {
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
          apiService: api,
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
