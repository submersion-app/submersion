import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_editing.dart';

/// The cylinder the dive editor's Add switch picks: the first breathing
/// cylinder not breathed at the new switch's time.
void main() {
  const back = DiveTank(id: 'back', gasMix: GasMix(o2: 21));
  const deco = DiveTank(
    id: 'deco',
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
    order: 1,
  );
  const airSuit = DiveTank(
    id: 'air-suit',
    gasMix: GasMix(o2: 21),
    role: TankRole.suitInflation,
    order: 2,
  );
  const argon = DiveTank(
    id: 'argon',
    gasMix: GasMix(o2: 0),
    role: TankRole.suitInflation,
    order: 3,
  );

  GasSwitch switchTo(String tankId, int t) => GasSwitch(
    id: 'gs-$tankId-$t',
    diveId: 'dive-1',
    timestamp: t,
    tankId: tankId,
    createdAt: DateTime(2026),
  );

  String? pick(List<DiveTank> tanks, List<GasSwitch> switches, int t) =>
      newGasSwitchTank(
        tanks: tanks,
        switches: switches,
        timestamp: t,
        startingTankId: 'back',
      )?.id;

  test('the first cylinder not in use at the new switch\'s time', () {
    expect(pick(const [back, deco], const [], 60), 'deco');
    expect(pick(const [back, deco], [switchTo('deco', 600)], 660), 'back');
  });

  test('a switch to a suit bottle counts against the cylinder on its mix', () {
    // The diver is on the back gas after the downloaded switch to the air
    // bottle, so the new switch goes to the deco gas, not back to back gas.
    expect(
      pick(const [back, deco, airSuit], [switchTo('air-suit', 600)], 660),
      'deco',
    );
  });

  test('a switch to a bottle on no breathing mix leaves the gas as it was', () {
    expect(
      pick(
        const [back, deco, argon],
        [switchTo('deco', 600), switchTo('argon', 900)],
        960,
      ),
      'back',
    );
  });

  test('never a suit bottle, and none without a breathing cylinder', () {
    expect(pick(const [airSuit, back], const [], 60), 'back');
    expect(pick(const [airSuit], const [], 60), isNull);
  });
}
