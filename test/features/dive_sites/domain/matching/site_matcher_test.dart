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

void main() {
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
