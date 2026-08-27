import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/best_mix.dart';

/// Vectors computed with python3 and reproduced in the spec. If one does not
/// match, report BLOCKED. Do not edit the constant.

const _feetPerMeter = 3.28084;

BestMixResult _at(
  double depthMeters, {
  double ppO2 = 1.4,
  double endLimit = 30,
  bool o2Narcotic = true,
}) => computeBestMix(
  BestMixInputs(
    depthMeters: depthMeters,
    ppO2Limit: ppO2,
    endLimitMeters: endLimit,
    o2Narcotic: o2Narcotic,
  ),
);

void main() {
  group('computeBestMix at 111 ft (the reported regression)', () {
    const depth = 111 / _feetPerMeter;
    final r = _at(depth);

    test('ideal fraction is 31.94 percent', () {
      expect(r.idealO2Percent, closeTo(31.94, 0.05));
    });

    test('oxygen rounds DOWN to 31, never up to 32', () {
      expect(r.recommended.mix.roundedO2, 31);
      expect(r.nitroxAlternative!.mix.name, 'EAN31');
    });

    test('the recommended mix MOD is deeper than the target depth', () {
      expect(r.recommended.modMeters, greaterThan(depth));
      expect(r.recommended.modMeters, closeTo(35.16, 0.05));
      // 4.4 ft of margin, where EAN32 had none.
      expect(r.recommended.marginMeters * _feetPerMeter, closeTo(4.4, 0.2));
    });

    test('EAN31 alone busts the END limit and the warn density', () {
      final nitrox = r.nitroxAlternative!;
      expect(nitrox.endMeters, closeTo(33.83, 0.05));
      expect(nitrox.exceedsEndLimit, isTrue);
      expect(nitrox.densityGPerL, closeTo(5.331, 0.02));
      expect(nitrox.exceedsWarnDensity, isTrue);
    });

    test('adding 10 percent helium fixes both narcosis and density', () {
      expect(r.recommended.mix.name, 'Tx 31/10');
      expect(r.recommended.endMeters, closeTo(29.45, 0.05));
      expect(r.recommended.exceedsEndLimit, isFalse);
      expect(r.recommended.densityGPerL, closeTo(4.894, 0.02));
      expect(r.recommended.exceedsWarnDensity, isFalse);
    });

    test('the advisory standard mix also covers the depth', () {
      expect(r.nearestStandardMix, isNotNull);
      expect(r.nearestStandardMix!.roundedO2, 30);
      expect(r.nearestStandardMix!.mod(ppO2: 1.4), greaterThanOrEqualTo(depth));
    });
  });

  group('rounding direction is always toward safety', () {
    test('the recommended mix is breathable at every depth 40-180 ft', () {
      for (var ft = 40; ft <= 180; ft += 1) {
        final depth = ft / _feetPerMeter;
        final r = _at(depth);
        expect(
          r.recommended.modMeters,
          greaterThanOrEqualTo(depth - 1e-6),
          reason: 'recommended mix must be breathable at $ft ft',
        );
        expect(
          r.recommended.marginMeters,
          greaterThanOrEqualTo(-1e-6),
          reason: 'margin must never be negative at $ft ft',
        );
      }
    });

    test('the advisory standard mix is never shallower than the depth', () {
      for (var ft = 40; ft <= 180; ft += 1) {
        final depth = ft / _feetPerMeter;
        final r = _at(depth);
        if (r.nearestStandardMix != null) {
          expect(
            r.nearestStandardMix!.mod(ppO2: 1.4),
            greaterThanOrEqualTo(depth - 1e-6),
            reason: 'advisory mix must cover $ft ft',
          );
        }
      }
    });

    test('a nitrox alternative is offered only when helium was added', () {
      // Shallow: no helium needed, so no alternative to offer.
      final shallow = _at(25);
      expect(shallow.recommended.mix.he, 0);
      expect(shallow.nitroxAlternative, isNull);

      // Deep: helium added, alternative present and helium-free.
      final deep = _at(50);
      expect(deep.recommended.mix.he, greaterThan(0));
      expect(deep.nitroxAlternative, isNotNull);
      expect(deep.nitroxAlternative!.mix.he, 0);
    });
  });

  group('helium', () {
    test('adds no helium when the nitrox mix is within the END limit', () {
      final r = _at(25);
      expect(r.recommended.mix.he, 0);
      expect(r.recommended.mix.isTrimix, isFalse);
      expect(r.recommended.exceedsEndLimit, isFalse);
    });

    test('adds helium when END would be exceeded, rounded up to 5 percent', () {
      final r = _at(50);
      expect(r.recommended.mix.he, greaterThan(0));
      expect(r.recommended.mix.he % 5, closeTo(0, 1e-9));
      expect(r.recommended.mix.isTrimix, isTrue);
      expect(r.recommended.endMeters, lessThanOrEqualTo(30 + 1e-6));
    });

    test('helium always lands END at or inside the limit, 40-100 m', () {
      for (var m = 40; m <= 100; m += 1) {
        final r = _at(m.toDouble());
        expect(
          r.recommended.endMeters,
          lessThanOrEqualTo(30 + 1e-6),
          reason: 'END must be inside the limit at $m m',
        );
        expect(r.recommended.exceedsEndLimit, isFalse);
      }
    });

    test('respects a tighter END limit', () {
      expect(
        _at(50, endLimit: 24).recommended.mix.he,
        greaterThan(_at(50, endLimit: 30).recommended.mix.he),
      );
    });

    test('a permissive END limit leaves the mix helium-free', () {
      final r = _at(60, endLimit: 60);
      expect(r.recommended.mix.he, 0);
      expect(r.nitroxAlternative, isNull);
    });
  });

  group('density', () {
    test('a deep helium-free mix trips the critical ceiling', () {
      // END limit set permissively so no helium is added; density then bites.
      final r = _at(60, endLimit: 60);
      expect(r.recommended.mix.he, 0);
      expect(r.recommended.exceedsCriticalDensity, isTrue);
    });

    test('a shallow mix is comfortably under both thresholds', () {
      final r = _at(18);
      expect(r.recommended.exceedsWarnDensity, isFalse);
      expect(r.recommended.exceedsCriticalDensity, isFalse);
    });
  });
}
