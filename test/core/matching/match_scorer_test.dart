import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/matching/match_scorer.dart';

void main() {
  group('bandScore', () {
    test('returns 1.0 at or below full', () {
      expect(bandScore(0, full: 5, zero: 15), 1.0);
      expect(bandScore(5, full: 5, zero: 15), 1.0);
    });

    test('returns 0.0 at or above zero', () {
      expect(bandScore(15, full: 5, zero: 15), 0.0);
      expect(bandScore(100, full: 5, zero: 15), 0.0);
    });

    test('interpolates linearly between full and zero', () {
      // 8 on [5, 15] -> 1 - (8-5)/(15-5) = 0.7
      expect(bandScore(8, full: 5, zero: 15), closeTo(0.7, 1e-9));
      // midpoint
      expect(bandScore(10, full: 5, zero: 15), closeTo(0.5, 1e-9));
    });

    test('a full: 0 band scores a 0 value as 1.0 (missing-data sentinel)', () {
      expect(bandScore(0, full: 0, zero: 5), 1.0);
    });

    test('infinity scores 0.0 (percent-depth guard sentinel)', () {
      expect(bandScore(double.infinity, full: 0.10, zero: 0.20), 0.0);
    });
  });

  group('MatchScorer.score', () {
    const scorer = MatchScorer(
      timeWeight: 0.50,
      depthWeight: 0.30,
      durationWeight: 0.20,
      timeFull: 5,
      timeZero: 15,
      depthFull: 0.10,
      depthZero: 0.20,
      durationFull: 3,
      durationZero: 10,
    );

    test('perfect match scores 1.0', () {
      expect(
        scorer.score(timeValue: 0, depthValue: 0, durationValue: 0),
        closeTo(1.0, 1e-9),
      );
    });

    test('weights each sub-score', () {
      // time 8min -> 0.7, depth/duration perfect -> composite
      // 0.7*0.5 + 1*0.3 + 1*0.2 = 0.85
      expect(
        scorer.score(timeValue: 8, depthValue: 0, durationValue: 0),
        closeTo(0.85, 1e-9),
      );
    });

    test(
      'without gate, zero time still allows depth+duration to contribute',
      () {
        // time >= 15 -> timeScore 0; depth+duration perfect -> 0.3 + 0.2 = 0.5
        expect(
          scorer.score(timeValue: 20, depthValue: 0, durationValue: 0),
          closeTo(0.5, 1e-9),
        );
      },
    );

    test('gateOnZeroTime short-circuits to 0.0 when time score is zero', () {
      const gated = MatchScorer(
        timeWeight: 0.50,
        depthWeight: 0.30,
        durationWeight: 0.20,
        timeFull: 5,
        timeZero: 15,
        depthFull: 0.10,
        depthZero: 0.20,
        durationFull: 3,
        durationZero: 10,
        gateOnZeroTime: true,
      );
      expect(gated.score(timeValue: 20, depthValue: 0, durationValue: 0), 0.0);
      // still scores normally within the window
      expect(
        gated.score(timeValue: 8, depthValue: 0, durationValue: 0),
        closeTo(0.85, 1e-9),
      );
    });
  });
}
