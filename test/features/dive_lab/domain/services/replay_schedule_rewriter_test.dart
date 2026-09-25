import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/replay_schedule_rewriter.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const back = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 200,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
);
const deco50 = DiveTank(
  id: 'deco50',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);
const bailout = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 32),
  role: TankRole.bailout,
);

List<int> _times() => [for (var t = 0; t <= 2400; t += 10) t];
List<double> _depths() => [
  for (var t = 0; t <= 2400; t += 10) t < 1800 ? 40.0 : 15.0,
];

void main() {
  test('switchGas to a hypothetical tank adds it and breathes it from T', () {
    final s = TankSchedule.fromDive(tanks: const [back], switches: const []);
    final r = rewriteScheduleForReplay(
      actual: s,
      interventions: const [
        SwitchGasIntervention(
          tank: HypotheticalTankRef(
            gasMix: GasMix(o2: 50),
            volumeLiters: 11.1,
            startPressureBar: 200,
          ),
        ),
      ],
      branchTimestamp: 1800,
      timestamps: _times(),
      depths: _depths(),
      maxPpO2: 1.6,
    );
    expect(r.tanks, hasLength(2));
    expect(r.tankIdAt(1799), 'back');
    expect(r.tankAt(1800)!.gasMix.o2, 50);
  });

  test('loseTank removes the tank and substitutes by depth after T', () {
    final s = TankSchedule.fromDive(
      tanks: const [back, deco50],
      switches: const [ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50')],
    );
    final r = rewriteScheduleForReplay(
      actual: s,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
      branchTimestamp: 1000,
      timestamps: _times(),
      depths: _depths(),
      maxPpO2: 1.6,
    );
    expect(r.tanks.map((t) => t.id), ['back']);
    expect(r.tankIdAt(2000), 'back');
  });

  test('bailOut breathes only bailout tanks from T', () {
    final s = TankSchedule.fromDive(
      tanks: const [back, bailout],
      switches: const [],
    );
    final r = rewriteScheduleForReplay(
      actual: s,
      interventions: const [BailOutIntervention()],
      branchTimestamp: 1800,
      timestamps: _times(),
      depths: _depths(),
      maxPpO2: 1.6,
    );
    expect(r.tankIdAt(1799), 'back');
    expect(r.tankIdAt(1800), 'bo');
    expect(r.tankIdAt(2400), 'bo');
  });

  test('no interventions returns the actual schedule unchanged', () {
    final s = TankSchedule.fromDive(tanks: const [back], switches: const []);
    expect(
      rewriteScheduleForReplay(
        actual: s,
        interventions: const [],
        branchTimestamp: 100,
        timestamps: _times(),
        depths: _depths(),
        maxPpO2: 1.6,
      ),
      same(s),
    );
  });
}
