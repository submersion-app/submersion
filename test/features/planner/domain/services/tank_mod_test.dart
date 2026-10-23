import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';

/// A cylinder's MOD (issue #3567): a default worked out from its mix and the
/// ppO2 limit its role calls for, unless the diver has set one by hand.
void main() {
  const bottom = 1.4;
  const deco = 1.6;
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
          deco,
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
          deco,
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
          decoPpO2: 1.5,
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
      expect(effectiveModMeters(t, bottomPpO2: 1.2, decoPpO2: 1.4), 21);
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
      expect(ppO2AtDepth(ean50, mod), closeTo(deco, 1e-9));
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
      expect(check.limitPpO2, deco);
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
  });

  group('ascent gases', () {
    test('carry each tank effective MOD', () {
      final gases = ascentGasesFor(
        [
          const DiveTank(id: 'b', gasMix: tx1845),
          tank(ean40, role: TankRole.deco, override: 21),
          tank(ean50, role: TankRole.deco),
        ],
        bottomPpO2: bottom,
        decoPpO2: deco,
      );
      expect(gases, hasLength(3));
      expect(gases[0].maxPpO2Mod, closeTo((1.4 / 0.18 - 1) * 10, 1e-9));
      expect(gases[1].maxPpO2Mod, 21);
      expect(gases[2].maxPpO2Mod, closeTo(22, 1e-9));
      expect(gases[2].fN2, closeTo(0.5, 1e-9));
      expect(gases[0].fHe, closeTo(0.45, 1e-9));
    });
  });
}
