import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';

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

Dive _diveWithBareSite(String id, DiveSite site, {GeoPoint? gps}) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: gps,
  site: site,
);

const _bareSite = DiveSite(id: 'bare', name: 'Typed Twice');

/// Resolving a suggested site without linking the dive, for an editing
/// sitting that holds the link until Save (issue #4527, plan 4). Split from
/// site_matching_service_test.dart, whose mocks it shares.
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

  // A sitting holds the dive's link until Save (issue #4527, plan 4): the
  // suggestion only needs the site, made at once when it is the catalogue's.
  group('resolveCandidate', () {
    setUp(() {
      when(
        sites.createSite(any, classification: anyNamed('classification')),
      ).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-${s.name}');
      });
    });

    test('an existing candidate resolves to it and links nothing', () async {
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
        ],
      );
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(33))]);

      final resolved = await s.resolveCandidate('d1', 's1');

      expect(resolved.site.id, 's1');
      expect(resolved.createdSiteIds, isEmpty);
      verifyNever(dives.setSite(any, any));
    });

    test('a catalogue candidate is adopted, reported as created, and '
        'nothing is linked', () async {
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_1',
          name: 'Wreck',
          location: GeoPoint(0, 0),
          source: 'osm',
        ),
      ];
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(22))]);

      final resolved = await s.resolveCandidate('d1', 'osm_1');

      expect(resolved.site.id, 'new-Wreck');
      expect(resolved.createdSiteIds, ['new-Wreck']);
      verifyNever(dives.setSite(any, any));
    });

    test('a catalogue candidate near a site of the diver\'s resolves to '
        'that site', () async {
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_1',
          name: 'Wreck',
          location: GeoPoint(0, 0),
          source: 'osm',
        ),
      ];
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(22))]);
      // The diver made a site right there after the proposals were made.
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => [
          DiveSite(id: 'mine', name: 'My wreck', location: _eastMeters(40)),
        ],
      );
      await s.computeProposals([_diveAt('d1', _eastMeters(22))]);

      final resolved = await s.resolveCandidate('d1', 'osm_1');

      expect(resolved.site.id, 'mine');
      expect(resolved.createdSiteIds, isEmpty);
      verifyNever(
        sites.createSite(any, classification: anyNamed('classification')),
      );
    });

    test(
      'a catalogue site already adopted resolves to the adopted one',
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
        await s.computeProposals([_diveAt('d1', _eastMeters(22))]);
        when(
          sites.getSiteByCatalogueId('osm_1', diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => const DiveSite(id: 'adopted', name: 'Wreck'));

        final resolved = await s.resolveCandidate('d1', 'osm_1');

        expect(resolved.site.id, 'adopted');
        expect(resolved.createdSiteIds, isEmpty);
        verifyNever(dives.setSite(any, any));
      },
    );

    test('the dive\'s own site is not a candidate to resolve', () async {
      final s = service();
      await s.computeProposals([
        _diveWithBareSite('d1', _bareSite, gps: _eastMeters(10)),
      ]);

      expect(
        () => s.resolveCandidate(
          'd1',
          SiteMatchingService.currentSiteCandidateId('bare'),
        ),
        throwsArgumentError,
      );
    });

    test('an unknown candidate throws', () async {
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(22))]);

      expect(() => s.resolveCandidate('d1', 'nope'), throwsStateError);
    });

    test('applyConfirmed still links what it resolves', () async {
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
        ],
      );
      final s = service();
      await s.computeProposals([_diveAt('d1', _eastMeters(33))]);

      await s.applyConfirmed([const ConfirmedMatch('d1', 's1')]);

      verify(dives.setSite('d1', 's1')).called(1);
    });
  });

  group('createSite', () {
    test(
      'creates the site under the diver, links nothing, fills altitude',
      () async {
        when(
          sites.createSite(any, classification: anyNamed('classification')),
        ).thenAnswer((inv) async {
          final s = inv.positionalArguments.first as DiveSite;
          return s.copyWith(id: 'new-${s.name}');
        });
        when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});
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

        final created = await s.createSite(
          const DiveSite(id: 'x', name: 'Wall', location: GeoPoint(1, 2)),
        );

        expect(created.id, 'new-Wall');
        final saved =
            verify(sites.createSite(captureAny)).captured.single as DiveSite;
        expect(saved.diverId, 'diver-1');
        verifyNever(dives.setSite(any, any));
        await pumpEventQueue();
        verify(sites.updateSiteAltitude('new-Wall', 3.0)).called(1);
      },
    );
  });

  // Code review: the site exists once it is written, and a sitting waiting
  // for it must not also wait on the network for its altitude.
  group('the altitude lookup does not hold the answer', () {
    late Completer<double?> lookup;

    SiteMatchingService slowService() => SiteMatchingService(
      siteRepository: sites,
      catalogue: catalogue,
      adoption: CatalogueAdoptionService(siteRepository: sites),
      diveRepository: dives,
      mediaRepository: media,
      diverId: 'diver-1',
      thresholds: SiteMatchSensitivity.balanced.thresholds,
      runInTransaction: (body) => body(),
      fetchElevation: (_) => lookup.future,
    );

    setUp(() {
      lookup = Completer<double?>();
      when(
        sites.createSite(any, classification: anyNamed('classification')),
      ).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-${s.name}');
      });
      when(sites.updateSiteAltitude(any, any)).thenAnswer((_) async {});
    });

    test('createSite answers before the altitude, which lands after', () async {
      final created = await slowService()
          .createSite(
            const DiveSite(id: 'x', name: 'Wall', location: GeoPoint(1, 2)),
          )
          .timeout(const Duration(seconds: 1));

      expect(created.id, 'new-Wall');
      lookup.complete(3.0);
      await pumpEventQueue();
      verify(sites.updateSiteAltitude('new-Wall', 3.0)).called(1);
    });

    test('resolveCandidate answers before the altitude', () async {
      catalogue.sites = const [
        CatalogueSite(
          id: 'osm_1',
          name: 'Wreck',
          location: GeoPoint(0, 0),
          source: 'osm',
        ),
      ];
      final s = slowService();
      await s.computeProposals([_diveAt('d1', _eastMeters(22))]);

      final resolved = await s
          .resolveCandidate('d1', 'osm_1')
          .timeout(const Duration(seconds: 1));

      expect(resolved.site.id, 'new-Wreck');
      lookup.complete(5.0);
      await pumpEventQueue();
      verify(sites.updateSiteAltitude('new-Wreck', 5.0)).called(1);
    });
  });
}
