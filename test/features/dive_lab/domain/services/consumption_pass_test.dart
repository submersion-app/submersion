import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/consumption_pass.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const back = DiveTank(
  id: 'back',
  volume: 10,
  startPressure: 200,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
);
const deco = DiveTank(
  id: 'deco',
  volume: 10,
  startPressure: 100,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);

void main() {
  test('ideal gas, constant depth: hand-computed pressure drop', () {
    // 10 min at 30 m (4 bar) at 20 L/min = 800 L; 10 L tank: 80 bar drop.
    // (1e-6 tolerance: the EN13319 depth constant is not exactly 0.1 bar/m.)
    final ts = [for (var t = 0; t <= 600; t += 60) t];
    final depths = List.filled(ts.length, 30.0);
    final schedule = TankSchedule.fromDive(tanks: const [back], switches: []);
    final out = simulateConsumption(
      timestamps: ts,
      depths: depths,
      schedule: schedule,
      startPressures: const {'back': 200.0},
      sacLpmAt: (_) => 20.0,
      environment: DiveEnvironment.standard,
      gasModel: GasModel.ideal,
      reservePressureBar: 50,
    );
    final b = out.single;
    expect(b.litersUsed, closeTo(800, 1e-6));
    expect(b.endPressureBar, closeTo(120, 1e-6));
    expect(b.reserveReachedAtSeconds, isNull);
    expect(b.emptyAtSeconds, isNull);
    expect(b.source, PressureSource.estimated);
  });

  test('reserve and empty instants are the first crossing samples', () {
    // 40 m (5 bar), 30 L/min = 150 L/min = 15 bar/min on a 10 L tank.
    // From 200 bar: reserve 50 after 10 min, empty after 13.33 min.
    final ts = [for (var t = 0; t <= 1200; t += 60) t];
    final depths = List.filled(ts.length, 40.0);
    final schedule = TankSchedule.fromDive(tanks: const [back], switches: []);
    final out = simulateConsumption(
      timestamps: ts,
      depths: depths,
      schedule: schedule,
      startPressures: const {'back': 200.0},
      sacLpmAt: (_) => 30.0,
      environment: DiveEnvironment.standard,
      gasModel: GasModel.ideal,
      reservePressureBar: 50,
    ).single;
    expect(out.reserveReachedAtSeconds, 600);
    expect(out.emptyAtSeconds, 840);
    expect(out.endPressureBar, 0);
  });

  test('consumption follows the schedule across a switch', () {
    // 0-300 s on back at 30 m, 300-600 s on deco at 30 m, 20 L/min.
    final ts = [for (var t = 0; t <= 600; t += 60) t];
    final depths = List.filled(ts.length, 30.0);
    final schedule = TankSchedule.fromDive(
      tanks: const [back, deco],
      switches: const [ScenarioGasSwitch(timestamp: 300, tankId: 'deco')],
    );
    final out = simulateConsumption(
      timestamps: ts,
      depths: depths,
      schedule: schedule,
      startPressures: const {'back': 200.0, 'deco': 100.0},
      sacLpmAt: (_) => 20.0,
      environment: DiveEnvironment.standard,
      gasModel: GasModel.ideal,
      reservePressureBar: 50,
    );
    final b = out.firstWhere((t) => t.tankId == 'back');
    final d = out.firstWhere((t) => t.tankId == 'deco');
    expect(b.litersUsed, closeTo(400, 1e-6));
    expect(d.litersUsed, closeTo(400, 1e-6));
    expect(b.endPressureBar, closeTo(160, 1e-6));
    expect(d.endPressureBar, closeTo(60, 1e-6));
  });

  test('fromIndex skips earlier samples; unknown start stays unknown', () {
    final ts = [for (var t = 0; t <= 600; t += 60) t];
    final depths = List.filled(ts.length, 30.0);
    final schedule = TankSchedule.fromDive(tanks: const [back], switches: []);
    final out = simulateConsumption(
      timestamps: ts,
      depths: depths,
      schedule: schedule,
      startPressures: const {'back': null},
      sacLpmAt: (_) => 20.0,
      environment: DiveEnvironment.standard,
      gasModel: GasModel.ideal,
      reservePressureBar: 50,
      fromIndex: 5,
    ).single;
    expect(out.litersUsed, closeTo(400, 1e-6));
    expect(out.endPressureBar, isNull);
    expect(out.source, PressureSource.unknown);
  });
}
