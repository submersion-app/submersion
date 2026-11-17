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

/// A researched record whose position was read off a counting page's map
/// is offered from up to 2 km in every list matching shows, and nothing
/// else reaches past the outer radius (wider sources design, section 5).

GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _diveAt(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

const _bareSite = DiveSite(id: 'bare', name: 'Typed Twice');

CatalogueSite _site(String id, double metersEast) => CatalogueSite(
  id: id,
  name: id,
  location: _eastMeters(metersEast),
  source: 'osm',
);

CatalogueSite _researched(
  String id,
  double metersEast, {
  bool fromMap = false,
}) => CatalogueSite(
  id: id,
  name: id,
  location: _eastMeters(metersEast),
  source: 'research',
  trust: CatalogueTrust.researched,
  positionFromMap: fromMap,
);

void main() {
  late MockSiteRepository sites;
  late FakeSiteCatalogue catalogue;
  late MockDiveRepository dives;
  late MockMediaRepository media;

  SiteMatchingService service({
    SiteMatchSensitivity sensitivity = SiteMatchSensitivity.balanced,
  }) => SiteMatchingService(
    siteRepository: sites,
    catalogue: catalogue,
    adoption: CatalogueAdoptionService(siteRepository: sites),
    diveRepository: dives,
    mediaRepository: media,
    diverId: 'diver-1',
    thresholds: sensitivity.thresholds,
    runInTransaction: (body) => body(),
  );

  setUp(() {
    sites = MockSiteRepository();
    when(
      sites.getSiteByCatalogueId(any, diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => null);
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const []);
    catalogue = FakeSiteCatalogue();
    dives = MockDiveRepository();
    media = MockMediaRepository();
    when(media.getBestPhotoGpsForDives(any)).thenAnswer((_) async => const {});
    when(dives.setSite(any, any)).thenAnswer((_) async {});
  });

  test('a dive auto-matched to a verified site lists a map-placed record '
      '1.5 km away among its candidates', () async {
    catalogue.sites = [
      _site('site', 100),
      _researched('research_id_coral_garden', 1500, fromMap: true),
    ];

    final proposal = (await service().computeProposals([
      _diveAt('d1', const GeoPoint(0, 0)),
    ])).single;

    expect(proposal.status, ProposalStatus.clear);
    expect(proposal.recommendedCandidateId, 'site');
    expect(proposal.candidates.map((c) => c.id), [
      'site',
      'research_id_coral_garden',
    ]);
  });

  test('a verified or stated researched record 1.5 km away stays out of '
      'the candidates', () async {
    catalogue.sites = [
      _site('near', 100),
      _site('far', 1500),
      _researched('research_id_stated', 1500),
    ];

    final proposal = (await service().computeProposals([
      _diveAt('d1', const GeoPoint(0, 0)),
    ])).single;

    expect(proposal.candidates.map((c) => c.id), ['near']);
  });

  test('500 nearer records past the outer radius do not crowd out a '
      'map-placed record 1.9 km away', () async {
    catalogue.sites = [
      for (var i = 0; i < 500; i++) _site('wreck_$i', 1100 + i.toDouble()),
      _researched('research_id_coral_garden', 1900, fromMap: true),
    ];

    final proposal = (await service().computeProposals([
      _diveAt('d1', const GeoPoint(0, 0)),
    ])).single;

    expect(proposal.candidates.map((c) => c.id), ['research_id_coral_garden']);
  });

  test('at the relaxed setting, whose outer radius is the 2 km reach, 500 '
      'nearer records do not crowd out a map-placed record', () async {
    catalogue.sites = [
      for (var i = 0; i < 500; i++) _site('wreck_$i', 1000 + i.toDouble()),
      _researched('research_id_coral_garden', 1900, fromMap: true),
    ];

    final proposal = (await service(
      sensitivity: SiteMatchSensitivity.relaxed,
    ).computeProposals([_diveAt('d1', const GeoPoint(0, 0))])).single;

    expect(
      proposal.candidates.map((c) => c.id),
      contains('research_id_coral_garden'),
    );
  });

  test('a dive whose site has no position lists a map-placed record 1.5 km '
      'away', () async {
    catalogue.sites = [
      _researched('research_id_coral_garden', 1500, fromMap: true),
    ];

    final proposal = (await service().computeProposals([
      Dive(
        id: 'd1',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1),
        maxDepth: 18,
        entryLocation: _eastMeters(0),
        site: _bareSite,
      ),
    ])).single;

    expect(proposal.candidates.first.isCurrentSite, isTrue);
    expect(
      proposal.candidates.map((c) => c.id),
      contains('research_id_coral_garden'),
    );
  });
}
