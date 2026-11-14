import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
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

void main() {
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
