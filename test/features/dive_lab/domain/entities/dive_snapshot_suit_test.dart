import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_snapshot.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A `.sublab` file carries breathing gas only (issue #4243): no suit
/// inflation bottle, no switch aimed at one and no pressure series for one,
/// so nothing in the file names a tank the file does not carry.
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

  List<TankPressureSample> series(double bar) => [
    TankPressureSample(timestamp: 0, pressureBar: bar),
    TankPressureSample(timestamp: 600, pressureBar: bar - 10),
  ];

  DiveSnapshot snapshot({String orphan = 'transmitter-only'}) =>
      DiveSnapshot.fromDive(
        dive: Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2026, 5, 3, 10),
          tanks: const [back, deco, airSuit, argon],
        ),
        profile: const [],
        gasSwitches: const [
          ScenarioGasSwitch(timestamp: 600, tankId: 'deco'),
          ScenarioGasSwitch(timestamp: 900, tankId: 'air-suit'),
          ScenarioGasSwitch(timestamp: 1200, tankId: 'argon'),
        ],
        tankPressures: {
          'back': series(200),
          'air-suit': series(180),
          'argon': series(150),
          orphan: series(190),
        },
      );

  test('a switch to a bottle moves to the cylinder on its mix, or goes', () {
    expect(snapshot().gasSwitches, const [
      ScenarioGasSwitch(timestamp: 600, tankId: 'deco'),
      ScenarioGasSwitch(timestamp: 900, tankId: 'back'),
    ]);
  });

  test('a bottle\'s pressure series is left out, every other kept', () {
    expect(snapshot().tankPressures.keys, ['back', 'transmitter-only']);
  });
}
