import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_ppo2_limits.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';

/// A cylinder's MOD (issue #3567): a default worked out from its mix and the
/// ppO2 limit its role calls for, unless the diver has set one by hand.
void main() {
  const bottom = 1.4;
  const deco = DecoPpO2Limits(flat: 1.6);
  const air = GasMix(o2: 21);
  const ean32 = GasMix(o2: 32);
  const ean40 = GasMix(o2: 40);
  const ean50 = GasMix(o2: 50);
  const oxygen = GasMix(o2: 100);
  const tx1845 = GasMix(o2: 18, he: 45);

  DiveTank tank(
    GasMix gas, {
    TankRole role = TankRole.backGas,
    double? override,
  }) => DiveTank(id: 't', gasMix: gas, role: role, decoSwitchDepth: override);

  group('the ppO2 limit a role calls for', () {
    test('deco gas and the oxygen supply use the deco limit', () {
      for (final role in [TankRole.deco, TankRole.oxygenSupply]) {
        expect(
          modPpO2For(role, ean50, bottomPpO2: bottom, decoPpO2: deco),
          deco.flat,
          reason: role.name,
        );
      }
    });

    test('back gas, stage and the rest use the bottom limit', () {
      for (final role in [
        TankRole.backGas,
        TankRole.stage,
        TankRole.sidemountLeft,
        TankRole.sidemountRight,
        TankRole.pony,
        TankRole.diluent,
      ]) {
        expect(
          modPpO2For(role, ean40, bottomPpO2: bottom, decoPpO2: deco),
          bottom,
          reason: role.name,
        );
      }
    });

    test('a bailout richer than air uses the deco limit', () {
      for (final gas in [ean32, ean50, oxygen]) {
        expect(
          modPpO2For(TankRole.bailout, gas, bottomPpO2: bottom, decoPpO2: deco),
          deco.flat,
          reason: gas.name,
        );
      }
    });

    test('an air or leaner bailout uses the bottom limit', () {
      for (final gas in [air, tx1845]) {
        expect(
          modPpO2For(TankRole.bailout, gas, bottomPpO2: bottom, decoPpO2: deco),
          bottom,
          reason: gas.name,
        );
      }
    });

    test('a diluent uses its own CCR Dil MOD limit when given one', () {
      expect(
        modPpO2For(
          TankRole.diluent,
          ean40,
          bottomPpO2: bottom,
          decoPpO2: deco,
          diluentPpO2: 1.6,
        ),
        1.6,
      );
    });

    test('a diluent falls back to the bottom limit with no Dil MOD', () {
      expect(
        modPpO2For(TankRole.diluent, ean40, bottomPpO2: bottom, decoPpO2: deco),
        bottom,
      );
    });
  });

  group('default MOD', () {
    test('EAN40 as deco gas: 30 m at 1.6', () {
      expect(
        defaultModMeters(
          TankRole.deco,
          ean40,
          bottomPpO2: bottom,
          decoPpO2: deco,
        ),
        closeTo(30, 1e-9),
      );
    });

    test('EAN40 as a stage: 25 m at 1.4', () {
      expect(
        defaultModMeters(
          TankRole.stage,
          ean40,
          bottomPpO2: bottom,
          decoPpO2: deco,
        ),
        closeTo(25, 1e-9),
      );
    });

    test('follows the limits it is given', () {
      expect(
        defaultModMeters(
          TankRole.deco,
          ean50,
          bottomPpO2: bottom,
          decoPpO2: const DecoPpO2Limits(flat: 1.5),
        ),
        closeTo(20, 1e-9),
      );
    });

    test('a gas with no oxygen has no MOD', () {
      expect(
        defaultModMeters(
          TankRole.backGas,
          const GasMix(o2: 0, he: 100),
          bottomPpO2: bottom,
          decoPpO2: deco,
        ),
        0,
      );
    });

    test('EAN40 as a diluent follows the CCR Dil MOD limit', () {
      expect(
        defaultModMeters(
          TankRole.diluent,
          ean40,
          bottomPpO2: bottom,
          decoPpO2: deco,
          diluentPpO2: 1.6,
        ),
        closeTo(30, 1e-9),
      );
    });
  });

  group('effective MOD', () {
    test('is the default when nothing was set by hand', () {
      expect(
        effectiveModMeters(
          tank(ean40, role: TankRole.deco),
          bottomPpO2: bottom,
          decoPpO2: deco,
        ),
        closeTo(30, 1e-9),
      );
    });

    test('is the override when one is set, whatever the limits', () {
      final t = tank(ean40, role: TankRole.deco, override: 21);
      expect(effectiveModMeters(t, bottomPpO2: bottom, decoPpO2: deco), 21);
      expect(
        effectiveModMeters(
          t,
          bottomPpO2: 1.2,
          decoPpO2: const DecoPpO2Limits(flat: 1.4),
        ),
        21,
      );
    });
  });

  group('ppO2 at a depth', () {
    test('EAN40 at 21 m breathes 1.24', () {
      expect(ppO2AtDepth(ean40, 21), closeTo(1.24, 1e-9));
    });

    test('is the limit back at the default MOD', () {
      final mod = defaultModMeters(
        TankRole.deco,
        ean50,
        bottomPpO2: bottom,
        decoPpO2: deco,
      );
      expect(ppO2AtDepth(ean50, mod), closeTo(deco.flat, 1e-9));
    });
  });

  group('an override deeper than its limit allows', () {
    test('is flagged with the ppO2 it reaches and the limit', () {
      final check = modOverrideCheck(
        tank(ean50, role: TankRole.deco, override: 24),
        bottomPpO2: bottom,
        decoPpO2: deco,
      );
      expect(check, isNotNull);
      expect(check!.exceedsLimit, isTrue);
      expect(check.ppO2, closeTo(1.70, 1e-9));
      expect(check.limitPpO2, deco.flat);
    });

    test('a shallower override is not flagged', () {
      final check = modOverrideCheck(
        tank(ean50, role: TankRole.deco, override: 18),
        bottomPpO2: bottom,
        decoPpO2: deco,
      );
      expect(check!.exceedsLimit, isFalse);
      expect(check.ppO2, closeTo(1.40, 1e-9));
    });

    test('an override exactly at the default is not flagged', () {
      final check = modOverrideCheck(
        tank(ean40, role: TankRole.deco, override: 30),
        bottomPpO2: bottom,
        decoPpO2: deco,
      );
      expect(check!.exceedsLimit, isFalse);
    });

    test('a tank without an override has nothing to check', () {
      expect(
        modOverrideCheck(
          tank(ean40, role: TankRole.deco),
          bottomPpO2: bottom,
          decoPpO2: deco,
        ),
        isNull,
      );
    });

    test('in the plan water, an override at the flat default is caught', () {
      // EAN40 at 30 m is 1.60 on the flat model the editor shows, but 1.61
      // in seawater, where the schedule breathes it (issue #3566).
      const seawater = DiveEnvironment(
        waterDensityKgM3: DiveEnvironment.saltWaterDensity,
      );
      final flat = modOverrideCheckFor(
        TankRole.deco,
        ean40,
        30,
        bottomPpO2: bottom,
        decoPpO2: deco,
      );
      final inWater = modOverrideCheckFor(
        TankRole.deco,
        ean40,
        30,
        bottomPpO2: bottom,
        decoPpO2: deco,
        environment: seawater,
      );
      expect(flat.exceedsLimit, isFalse);
      expect(inWater.exceedsLimit, isTrue);
      expect(inWater.ppO2, closeTo(0.40 * seawater.pressureAtDepth(30), 1e-9));
    });

    test('in the plan water, the default switch depth is not flagged', () {
      // The same slack a default switch gets: an override typed at the
      // depth the plan would have switched at anyway raises nothing.
      const seawater = DiveEnvironment(
        waterDensityKgM3: DiveEnvironment.saltWaterDensity,
      );
      final check = modOverrideCheckFor(
        TankRole.deco,
        ean40,
        gasSwitchDepthMeters(0.40, maxPpO2: deco.flat, environment: seawater),
        bottomPpO2: bottom,
        decoPpO2: deco,
        environment: seawater,
      );
      expect(check.exceedsLimit, isFalse);
    });

    test('a diluent override is checked against the Dil MOD limit', () {
      final check = modOverrideCheck(
        tank(ean40, role: TankRole.diluent, override: 25),
        bottomPpO2: bottom,
        decoPpO2: deco,
        diluentPpO2: 1.6,
      );
      expect(check!.exceedsLimit, isFalse);
      expect(check.limitPpO2, 1.6);
    });
  });

  group('ascent gases', () {
    final salt = DiveEnvironment.forConditions(waterType: WaterType.salt);

    test('carry each tank effective MOD', () {
      final gases = ascentGasesFor(
        [
          const DiveTank(id: 'b', gasMix: tx1845),
          tank(ean40, role: TankRole.deco, override: 21),
          tank(ean50, role: TankRole.deco),
        ],
        bottomPpO2: bottom,
        decoPpO2: deco,
        environment: salt,
      );
      expect(gases, hasLength(3));
      expect(
        gases[0].maxPpO2Mod,
        closeTo(
          gasSwitchDepthMeters(0.18, maxPpO2: 1.4, environment: salt),
          1e-9,
        ),
      );
      // A MOD set by hand is used as typed, not converted to the water.
      expect(gases[1].maxPpO2Mod, 21);
      expect(
        gases[2].maxPpO2Mod,
        closeTo(
          gasSwitchDepthMeters(0.5, maxPpO2: 1.6, environment: salt),
          1e-9,
        ),
      );
      expect(gases[2].fN2, closeTo(0.5, 1e-9));
      expect(gases[0].fHe, closeTo(0.45, 1e-9));
    });

    test('a diluent tank carries the Dil MOD limit when given one', () {
      final gases = ascentGasesFor(
        [tank(ean40, role: TankRole.diluent)],
        bottomPpO2: bottom,
        decoPpO2: deco,
        environment: salt,
        diluentPpO2: 1.6,
      );
      expect(
        gases.single.maxPpO2Mod,
        closeTo(
          gasSwitchDepthMeters(0.4, maxPpO2: 1.6, environment: salt),
          1e-9,
        ),
      );
    });
  });

  group('per-O2-band deco ppO2 limits (issue #3580)', () {
    const bands = DecoPpO2Limits(
      flat: 1.6,
      bandsEnabled: true,
      band1: 1.6,
      band2: 1.5,
      band3: 1.4,
    );

    test('a deco gas up to 28% O2 uses band1', () {
      expect(
        modPpO2For(
          TankRole.deco,
          const GasMix(o2: 28),
          bottomPpO2: bottom,
          decoPpO2: bands,
        ),
        1.6,
      );
    });

    test('a deco gas from 28% up to 45% O2 uses band2', () {
      expect(
        modPpO2For(
          TankRole.deco,
          const GasMix(o2: 45),
          bottomPpO2: bottom,
          decoPpO2: bands,
        ),
        1.5,
      );
    });

    test('a deco gas above 45% O2 uses band3', () {
      expect(
        modPpO2For(TankRole.deco, ean50, bottomPpO2: bottom, decoPpO2: bands),
        1.4,
      );
    });

    test('band3 still covers pure O2 while the explicit depth is off', () {
      expect(
        modPpO2For(TankRole.deco, oxygen, bottomPpO2: bottom, decoPpO2: bands),
        1.4,
      );
    });

    test('bands off falls back to the flat value regardless of O2%', () {
      const flatOnly = DecoPpO2Limits(flat: 1.6);
      expect(
        modPpO2For(
          TankRole.deco,
          ean50,
          bottomPpO2: bottom,
          decoPpO2: flatOnly,
        ),
        1.6,
      );
    });
  });

  group('explicit MOD for 100% O2 (issue #3580)', () {
    const explicit = DecoPpO2Limits(
      flat: 1.6,
      explicitO2DepthEnabled: true,
      explicitO2DepthMeters: 6.0,
    );
    final salt = DiveEnvironment.forConditions(waterType: WaterType.salt);

    test(
      'a pure O2 deco gas gets the explicit depth, not the ppO2 formula',
      () {
        expect(
          defaultModMeters(
            TankRole.deco,
            oxygen,
            bottomPpO2: bottom,
            decoPpO2: explicit,
          ),
          6.0,
        );
      },
    );

    test('an O2 supply tank gets the explicit depth too', () {
      expect(
        defaultModMeters(
          TankRole.oxygenSupply,
          oxygen,
          bottomPpO2: bottom,
          decoPpO2: explicit,
        ),
        6.0,
      );
    });

    test('a non-pure deco gas is unaffected by the explicit depth', () {
      expect(
        defaultModMeters(
          TankRole.deco,
          ean50,
          bottomPpO2: bottom,
          decoPpO2: explicit,
        ),
        closeTo(22, 1e-9),
      );
    });

    test(
      'a diluent is never governed by the explicit depth, even with pure O2',
      () {
        expect(
          defaultModMeters(
            TankRole.diluent,
            oxygen,
            bottomPpO2: bottom,
            decoPpO2: explicit,
            diluentPpO2: 1.3,
          ),
          closeTo(3, 1e-9),
        );
      },
    );

    test(
      'ascentGasesFor gives the explicit depth directly, bypassing water',
      () {
        final gases = ascentGasesFor(
          [const DiveTank(id: 'o2', gasMix: oxygen, role: TankRole.deco)],
          bottomPpO2: bottom,
          decoPpO2: explicit,
          environment: salt,
        );
        // Not the salt-water switch depth for 1.6 bar pure O2 (which would be
        // a shade less than 6 m): the configured depth exactly, regardless of
        // water density.
        expect(gases.single.maxPpO2Mod, 6.0);
      },
    );

    test('a hand-set MOD on a pure O2 gas is checked against the explicit '
        'depth, not a ppO2 formula', () {
      final check = modOverrideCheckFor(
        TankRole.deco,
        oxygen,
        7.0,
        bottomPpO2: bottom,
        decoPpO2: explicit,
      );
      expect(check.exceedsLimit, isTrue);

      final shallower = modOverrideCheckFor(
        TankRole.deco,
        oxygen,
        5.0,
        bottomPpO2: bottom,
        decoPpO2: explicit,
      );
      expect(shallower.exceedsLimit, isFalse);
    });
  });
}
