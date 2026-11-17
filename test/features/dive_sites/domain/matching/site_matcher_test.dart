import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_matcher.dart';

const _balanced = MatchThresholds(
  innerRadiusMeters: 150,
  outerRadiusMeters: 1000,
  separationMeters: 75,
);

// ~0.001 deg longitude at the equator is ~111 m. Build points by metres east.
GeoPoint _origin() => const GeoPoint(0, 0);
GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

MatchCandidate _existing(String id, double metersEast) =>
    MatchCandidate(id: id, location: _eastMeters(metersEast), isExisting: true);
MatchCandidate _bundled(String id, double metersEast) => MatchCandidate(
  id: id,
  location: _eastMeters(metersEast),
  isExisting: false,
);

MatchCandidate _register(String id, double metersEast) => MatchCandidate(
  id: id,
  location: _eastMeters(metersEast),
  isExisting: false,
  isRegister: true,
);

MatchCandidate _researched(String id, double metersEast) => MatchCandidate(
  id: id,
  location: _eastMeters(metersEast),
  isExisting: false,
  isResearched: true,
);

MatchCandidate _mapPlaced(String id, double metersEast) => MatchCandidate(
  id: id,
  location: _eastMeters(metersEast),
  isExisting: false,
  isResearched: true,
  isMapPlaced: true,
);

void main() {
  group('a map-placed researched record (wider sources design, section 5)', () {
    SiteMatchOutcome match(
      List<MatchCandidate> candidates, [
      MatchThresholds thresholds = _balanced,
    ]) => matchDive(
      point: _origin(),
      candidates: candidates,
      thresholds: thresholds,
    );

    List<String> ids(SiteMatchOutcome out) =>
        (out as Suggested).candidates.map((r) => r.candidate.id).toList();

    test('a lone map-placed record 1.5 km away is suggested', () {
      final out = match([_mapPlaced('garden', 1500)]);

      expect(out, isA<Suggested>());
      expect(ids(out), ['garden']);
    });

    test('a verified site 100 m away is auto-matched past a map-placed '
        'record 120 m away', () {
      final out = match([_bundled('site', 100), _mapPlaced('garden', -120)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'site');
    });

    test('a verified site 140 m away is auto-matched past a map-placed '
        'record 80 m away', () {
      final out = match([_bundled('site', 140), _mapPlaced('garden', -80)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'site');
    });

    test('a stated researched record 80 m away still blocks a verified site '
        '140 m away', () {
      final out = match([_bundled('site', 140), _researched('garden', -80)]);

      expect(out, isA<Suggested>());
    });

    test('a map-placed record does not count as a dive site close behind a '
        'register record', () {
      final out = match([_register('wreck', 60), _mapPlaced('garden', -90)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'wreck');
    });

    test('map-placed reach is never below 2 km', () {
      final out = match([
        _mapPlaced('garden', 1500),
      ], SiteMatchSensitivity.strict.thresholds);

      expect(out, isA<Suggested>());
      expect(ids(out), ['garden']);
    });

    test('the map-placed reach is 2 km, or the outer radius when wider', () {
      const wide = MatchThresholds(
        innerRadiusMeters: 150,
        outerRadiusMeters: 3000,
        separationMeters: 50,
      );

      expect(mapPlacedReachMeters(_balanced), kMapPlacedReachMeters);
      expect(mapPlacedReachMeters(wide), 3000);
      expect(reachMeters(_mapPlaced('garden', 0), wide), 3000);
    });

    test('a verified record beyond the outer radius is still out of '
        'range', () {
      final out = match([_bundled('far', 1500)]);

      expect(out, isA<NoMatch>());
    });
  });

  group('a researched record (gathered from dive guides, not verified)', () {
    SiteMatchOutcome match(List<MatchCandidate> candidates) => matchDive(
      point: _origin(),
      candidates: candidates,
      thresholds: _balanced,
    );

    test('a lone researched record inside the inner radius is offered, '
        'not picked', () {
      final out = match([_researched('liberty', 40)]);

      expect(out, isA<Suggested>());
      expect((out as Suggested).candidates.single.candidate.id, 'liberty');
    });

    test('a verified dive site at 40 m is picked over a researched record '
        'at 400 m', () {
      final out = match([_bundled('site', 40), _researched('liberty', 400)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'site');
    });

    test('a researched record close behind a verified one holds back the '
        'automatic pick', () {
      final out = match([_bundled('site', 40), _researched('liberty', 60)]);

      expect(out, isA<Suggested>());
    });

    test("the diver's own site still wins over a nearer researched "
        'record', () {
      final out = match([_researched('liberty', 20), _existing('mine', 30)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'mine');
      expect(out.isExisting, isTrue);
    });
  });

  group('a register record (a charted wreck, a reef deployment)', () {
    SiteMatchOutcome match(List<MatchCandidate> candidates) => matchDive(
      point: _origin(),
      candidates: candidates,
      thresholds: _balanced,
    );

    test('a dive site inside the inner radius beats a nearer register '
        'record', () {
      final out = match([_register('wreck', 60), _bundled('site', 120)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'site');
      expect(out.isExisting, false);
    });

    test('a lone register record inside the inner radius is matched', () {
      final out = match([_register('wreck', 60)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'wreck');
    });

    test('a dive site outside the inner radius does not hold one back', () {
      final out = match([_register('wreck', 60), _bundled('site', 400)]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'wreck');
    });

    test('a dive site close behind a register record keeps it from being '
        'picked on its own', () {
      // At the strict setting the dive site, 120 m away, is outside the
      // 100 m inside which a match is made, but it is too near the wreck
      // at 60 m to say the dive was on the wreck and not the site.
      const strict = MatchThresholds(
        innerRadiusMeters: 100,
        outerRadiusMeters: 500,
        separationMeters: 100,
      );
      SiteMatchOutcome strictly(List<MatchCandidate> candidates) => matchDive(
        point: _origin(),
        candidates: candidates,
        thresholds: strict,
      );

      final close = strictly([_register('wreck', 60), _bundled('site', 120)]);
      expect(close, isA<Suggested>());
      expect((close as Suggested).candidates.map((c) => c.candidate.id), [
        'wreck',
        'site',
      ]);

      // Well clear of it, the wreck is matched as before.
      final clear = strictly([_register('wreck', 60), _bundled('site', 300)]);
      expect(clear, isA<AutoMatch>());
      expect((clear as AutoMatch).siteId, 'wreck');
    });

    test('two register records too close to tell apart are suggested', () {
      final out = match([_register('a', 40), _register('b', 80)]);

      expect(out, isA<Suggested>());
      expect((out as Suggested).candidates, hasLength(2));
    });

    test('two dive sites too close to tell apart are suggested, with the '
        'register record still on the list', () {
      final out = match([
        _bundled('a', 100),
        _bundled('b', 120),
        _register('wreck', 10),
      ]);

      expect(out, isA<Suggested>());
      expect((out as Suggested).candidates.map((c) => c.candidate.id), [
        'wreck',
        'a',
        'b',
      ]);
    });

    test('the diver\'s own site still beats both', () {
      final out = match([
        _register('wreck', 10),
        _bundled('site', 60),
        _existing('mine', 140),
      ]);

      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'mine');
      expect(out.isExisting, true);
    });

    test('a candidate is a dive site unless it says otherwise', () {
      expect(_bundled('site', 1).isRegister, isFalse);
      expect(_existing('mine', 1).isRegister, isFalse);
    });
  });

  group('matchDive', () {
    test('no candidates in range -> NoMatch', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 5000)],
        thresholds: _balanced,
      );
      expect(out, isA<NoMatch>());
    });

    test('single existing within inner -> AutoMatch', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 40)],
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      final auto = out as AutoMatch;
      expect(auto.siteId, 'a');
      expect(auto.isExisting, true);
    });

    test('two existing within inner, too close -> Suggested', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 40), _existing('b', 80)], // gap 40 < 75
        thresholds: _balanced,
      );
      expect(out, isA<Suggested>());
      expect((out as Suggested).candidates.length, 2);
    });

    test('two existing within inner, well separated -> AutoMatch nearest', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 20), _existing('b', 120)], // gap 100 >= 75
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'a');
    });

    test('existing within inner beats closer bundled (precedence)', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_bundled('b', 30), _existing('a', 120)],
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      final auto = out as AutoMatch;
      expect(auto.siteId, 'a');
      expect(auto.isExisting, true);
    });

    test('only bundled within inner -> AutoMatch bundled', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_bundled('b', 50)],
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      final auto = out as AutoMatch;
      expect(auto.siteId, 'b');
      expect(auto.isExisting, false);
    });

    test(
      'single loose candidate (outside inner, inside outer) -> Suggested',
      () {
        final out = matchDive(
          point: _origin(),
          candidates: [_existing('a', 400)],
          thresholds: _balanced,
        );
        expect(out, isA<Suggested>());
        expect((out as Suggested).candidates.single.candidate.id, 'a');
      },
    );

    test('Suggested candidates are distance-sorted across both pools', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('far', 900), _bundled('near', 300)],
        thresholds: _balanced,
      );
      expect(out, isA<Suggested>());
      final s = out as Suggested;
      expect(s.candidates.first.candidate.id, 'near');
      expect(s.candidates.last.candidate.id, 'far');
    });
  });
}
