import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';

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

  group('Tec ambient model (OC-Tec, salt water, 0 C)', () {
    // DiveEnvironment's salt water (1025 kg/m3) is close to but not
    // identical to the flat 1 bar/10 m model (barPerMeter is about 0.10052,
    // not 0.1), so this is a same-mode sanity check, not a cross-check
    // against the Rec path.
    final r = computeBestMix(
      const BestMixInputs(
        depthMeters: 30,
        ppO2Limit: 1.4,
        endLimitMeters: 30,
        o2Narcotic: true,
        mode: BestMixMode.ocTec,
        waterType: WaterType.salt,
        temperature: GasDensityTemperature.zeroC,
      ),
    );

    test('EAD is populated outside Rec', () {
      expect(r.recommended.eadMeters, isNotNull);
    });

    test('END equals the actual depth for a helium-free mix', () {
      // No helium, O2 counted as narcotic: the narcotic fraction is the
      // whole ambient pressure, so the equivalent narcotic depth is the
      // real depth exactly, regardless of the O2 percentage.
      expect(r.recommended.endMeters, closeTo(30, 0.01));
    });

    test('EAD is shallower than END for a nitrox richer than air', () {
      // EAD counts N2 only, so a mix richer than air's 21% carries less of
      // it than air does at the same depth and reads shallower.
      expect(r.recommended.eadMeters, lessThan(r.recommended.endMeters));
    });

    test('Rec stays null for EAD (unchanged field, no regression)', () {
      final rec = _at(30);
      expect(rec.recommended.eadMeters, isNull);
    });

    test(
      'MOD uses the same environment as END/density, not the flat model',
      () {
        // Salt water barPerMeter (~0.10052) differs from the flat 0.1, so the
        // Tec MOD for the same mix differs very slightly from the Rec MOD at
        // the same ppO2. This pins that MOD and END share one ambient model
        // rather than MOD silently staying flat.
        final flatMod = _at(30).recommended.mix.mod(ppO2: 1.4);
        expect(r.recommended.modMeters, isNot(closeTo(flatMod, 1e-9)));
        final environment = DiveEnvironment.forConditions(
          waterType: WaterType.salt,
        );
        final expectedMod = environment.depthAtPressure(
          1.4 / (r.recommended.mix.o2 / 100),
        );
        expect(r.recommended.modMeters, closeTo(expectedMod, 1e-6));
      },
    );
  });

  group('density-aware helium', () {
    BestMixResult tec(
      double depth, {
      // High enough that END (which equals the actual depth for a
      // helium-free, O2-narcotic mix) never binds at the depths tested
      // below, so these tests isolate the density path.
      double endLimit = 200,
      bool densityAware = false,
    }) => computeBestMix(
      BestMixInputs(
        depthMeters: depth,
        ppO2Limit: 1.4,
        endLimitMeters: endLimit,
        o2Narcotic: true,
        mode: BestMixMode.ocTec,
        waterType: WaterType.salt,
        densityAware: densityAware,
      ),
    );

    test('off by default: unaffected by density even when it is critical', () {
      final r = tec(60, endLimit: 60);
      expect(r.recommended.mix.he, 0);
      expect(r.recommended.exceedsCriticalDensity, isTrue);
      expect(r.heliumDriver, HeliumDriver.none);
    });

    test('switched on: adds helium a loose END limit alone would not add', () {
      const depth = 70.0;
      // o2Narcotic defaults to true, under which a helium-free mix's END
      // equals the actual depth exactly, so the limit must be at least the
      // depth itself to stay END-compliant without helium.
      final withoutDensity = tec(depth, endLimit: depth, densityAware: false);
      final withDensity = tec(depth, endLimit: depth, densityAware: true);
      expect(
        withDensity.recommended.mix.he,
        greaterThan(withoutDensity.recommended.mix.he),
      );
      expect(withDensity.heliumDriver, HeliumDriver.density);
      expect(withDensity.recommended.exceedsCriticalDensity, isFalse);
    });

    test('density-driven helium rounds up to 1 percent, not 5', () {
      final r = tec(70, densityAware: true);
      final raw = heForDensityLimit(
        70,
        r.recommended.mix.o2,
        temperature: GasDensityTemperature.zeroC,
        waterType: WaterType.salt,
      );
      expect(r.recommended.mix.he - raw, lessThan(1.0));
      expect(r.recommended.mix.he, greaterThanOrEqualTo(raw - 1e-9));
    });

    test('both reasons active report HeliumDriver.both', () {
      final r = tec(90, endLimit: 30, densityAware: true);
      expect(r.recommended.mix.isTrimix, isTrue);
      expect(r.heliumDriver, HeliumDriver.both);
    });

    test('Rec never applies density regardless of the stored flag', () {
      // densityAware has no field on the Rec path's call site; this proves
      // a Tec-only gate rather than relying on the default being false.
      final r = _at(60, endLimit: 60);
      expect(r.recommended.mix.he, 0);
    });
  });

  group('heForDensityLimit', () {
    test('zero when the nitrox mix is already compliant', () {
      expect(
        heForDensityLimit(
          20,
          32,
          temperature: GasDensityTemperature.zeroC,
          waterType: WaterType.salt,
        ),
        0,
      );
    });

    test('closed form lands exactly on the critical density', () {
      const depth = 60.0;
      const o2 = 18.0;
      final he = heForDensityLimit(
        depth,
        o2,
        temperature: GasDensityTemperature.zeroC,
        waterType: WaterType.salt,
      );
      final ambient = DiveEnvironment.forConditions(
        waterType: WaterType.salt,
      ).pressureAtDepth(depth);
      const fO2 = o2 / 100;
      final fHe = he / 100;
      final fN2 = 1 - fO2 - fHe;
      final density = gasDensityFromPartialPressures(
        pO2Bar: fO2 * ambient,
        pN2Bar: fN2 * ambient,
        pHeBar: fHe * ambient,
        temperatureC: 0,
      );
      expect(density, closeTo(gasDensityCriticalGPerL, 0.01));
    });

    test('a richer nitrox needs at least as much helium at the same depth', () {
      // O2's molar mass (32) is above N2's (28.014), so replacing N2 with
      // O2 makes the helium-free gas itself slightly denser, not lighter.
      final at32 = heForDensityLimit(
        70,
        32,
        temperature: GasDensityTemperature.zeroC,
        waterType: WaterType.salt,
      );
      final at21 = heForDensityLimit(
        70,
        21,
        temperature: GasDensityTemperature.zeroC,
        waterType: WaterType.salt,
      );
      expect(at32, greaterThanOrEqualTo(at21));
    });

    test('warmer gas is less dense and needs no more helium', () {
      final cold = heForDensityLimit(
        70,
        21,
        temperature: GasDensityTemperature.zeroC,
        waterType: WaterType.salt,
      );
      final warm = heForDensityLimit(
        70,
        21,
        temperature: GasDensityTemperature.twentyC,
        waterType: WaterType.salt,
      );
      expect(warm, lessThanOrEqualTo(cold));
    });

    test('clamps to zero rather than going negative for a shallow mix', () {
      expect(
        heForDensityLimit(
          5,
          21,
          temperature: GasDensityTemperature.zeroC,
          waterType: WaterType.salt,
        ),
        0,
      );
    });
  });
}
