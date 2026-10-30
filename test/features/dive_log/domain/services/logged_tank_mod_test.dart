import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/logged_tank_mod.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';

/// The limit a logged cylinder's MOD is shown at (issue #3752): the
/// planner's role rule (issue #3567), with the dive's mode deciding whether
/// a diluent is one.
void main() {
  const air = GasMix(o2: 21);
  const ean32 = GasMix(o2: 32);
  const ean50 = GasMix(o2: 50);
  const oxygen = GasMix(o2: 100);

  group('loggedTankModLimit', () {
    test('bottom roles take the bottom limit on any dive', () {
      for (final role in [
        TankRole.backGas,
        TankRole.stage,
        TankRole.sidemountLeft,
        TankRole.sidemountRight,
        TankRole.pony,
      ]) {
        for (final mode in DiveMode.values) {
          expect(
            loggedTankModLimit(role, ean32, mode),
            ModLimitClass.bottom,
            reason: '${role.name} on ${mode.name}',
          );
        }
      }
    });

    test('deco gas and the oxygen supply take the deco limit', () {
      expect(
        loggedTankModLimit(TankRole.deco, ean50, DiveMode.oc),
        ModLimitClass.deco,
      );
      expect(
        loggedTankModLimit(TankRole.oxygenSupply, oxygen, DiveMode.ccr),
        ModLimitClass.deco,
      );
    });

    test('a bailout richer than air is a deco gas, air or leaner is not', () {
      expect(
        loggedTankModLimit(TankRole.bailout, ean50, DiveMode.ccr),
        ModLimitClass.deco,
      );
      expect(
        loggedTankModLimit(TankRole.bailout, air, DiveMode.ccr),
        ModLimitClass.bottom,
      );
    });

    test('a diluent takes the Dil MOD limit on a rebreather dive', () {
      for (final mode in [DiveMode.ccr, DiveMode.scr]) {
        expect(
          loggedTankModLimit(TankRole.diluent, air, mode),
          ModLimitClass.diluent,
          reason: mode.name,
        );
      }
    });

    test('a diluent left on an open-circuit dive takes the bottom limit', () {
      for (final mode in [DiveMode.oc, DiveMode.gauge]) {
        expect(
          loggedTankModLimit(TankRole.diluent, air, mode),
          ModLimitClass.bottom,
          reason: mode.name,
        );
      }
    });
  });

  group('modLimitPpO2', () {
    test('each limit reads its own setting', () {
      double ppO2(ModLimitClass limit) =>
          modLimitPpO2(limit, bottomPpO2: 1.4, decoPpO2: 1.6, diluentPpO2: 1.2);
      expect(ppO2(ModLimitClass.bottom), 1.4);
      expect(ppO2(ModLimitClass.deco), 1.6);
      expect(ppO2(ModLimitClass.diluent), 1.2);
    });
  });
}
