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

import 'site_matching_service_test.mocks.dart';

GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _diveAt(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository])
void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;

  // Pass-through transaction runner so apply runs without a real database.
  SiteMatchingService service() => SiteMatchingService(
    siteRepository: sites,
    apiService: api,
    diveRepository: dives,
    diverId: 'diver-1',
    thresholds: SiteMatchSensitivity.balanced.thresholds,
    runInTransaction: (body) => body(),
  );

  setUp(() {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
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
}
