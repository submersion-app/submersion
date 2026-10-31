import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/branch_state_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../support/synthetic_dives.dart';

DiveScenario _scenario(int branchSeconds) => DiveScenario(
  id: 's',
  diveId: 'd',
  name: 'n',
  branchSeconds: branchSeconds,
  mode: ScenarioMode.replay,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ScenarioRequest _request(
  SyntheticDive dive, {
  int branchSeconds = 900,
  Map<String, List<TankPressureSample>>? pressures,
  List<DiveTank>? tanks,
  double? fallbackSacLpm,
}) => ScenarioRequest(
  diveId: 'd',
  depths: dive.depths,
  timestamps: dive.timestamps,
  diveMode: DiveMode.oc,
  tanks: tanks ?? dive.tanks,
  gasSwitches: dive.switches,
  tankPressures: pressures ?? dive.tankPressures,
  fallbackSacLpm: fallbackSacLpm,
  scenario: _scenario(branchSeconds),
);

ProfileAnalysis _analyze(ScenarioRequest r) {
  final schedule = TankSchedule.fromDive(
    tanks: r.tanks,
    switches: r.gasSwitches,
  );
  return r.settings.buildAnalysisService().analyze(
    diveId: r.diveId,
    depths: r.depths,
    timestamps: r.timestamps,
    gasSegments: schedule.toGasSegments(),
  );
}

void main() {
  group('branchIndexFor', () {
    test('nearest sample, earlier on ties, clamped', () {
      const ts = [0, 10, 20, 30];
      expect(branchIndexFor(ts, 0), 0);
      expect(branchIndexFor(ts, 14), 1);
      expect(branchIndexFor(ts, 15), 1);
      expect(branchIndexFor(ts, 16), 2);
      expect(branchIndexFor(ts, 99), 3);
      expect(branchIndexFor(ts, -5), 0);
    });
  });

  group('buildBranchState', () {
    test('reads tissues, anchor, CNS, OTU, active tank at the branch', () {
      final dive = squareDive();
      final r = _request(dive, branchSeconds: 900);
      final actual = _analyze(r);
      final schedule = TankSchedule.fromDive(
        tanks: r.tanks,
        switches: r.gasSwitches,
      );
      final i = branchIndexFor(r.timestamps, 900);
      final b = buildBranchState(
        request: r,
        actual: actual,
        schedule: schedule,
        branchIndex: i,
      );
      expect(b.index, i);
      expect(b.runtimeSeconds, 900);
      expect(b.depthMeters, 40.0);
      expect(b.compartments, actual.decoStatuses[i].compartments);
      expect(b.gfLowCeilingAnchor, actual.decoStatuses[i].gfLowCeilingAnchor);
      expect(b.cnsPercent, actual.cnsCurve![i]);
      expect(b.otu, actual.otuCurve![i]);
      expect(b.activeTankId, 'back');
      expect(b.tissueState.gfLowCeilingAnchor, b.gfLowCeilingAnchor);
    });

    test('measured pressure and SAC from the active tank series', () {
      final dive = squareDive(sacLpm: 20);
      final r = _request(dive, branchSeconds: 900);
      final actual = _analyze(r);
      final schedule = TankSchedule.fromDive(
        tanks: r.tanks,
        switches: r.gasSwitches,
      );
      final b = buildBranchState(
        request: r,
        actual: actual,
        schedule: schedule,
        branchIndex: branchIndexFor(r.timestamps, 900),
      );
      expect(b.pressureSourceFor('back'), PressureSource.measured);
      // Generator: 200 bar minus 20 L/min x 5 bar (40 m) x 13 min of bottom
      // (900 s minus the 120 s descent) / 24 L = 1300 / 24, minus the descent
      // (2 min at a mean of 3 bar = 120 L, 5 bar on a 24 L tank).
      expect(b.pressureFor('back'), closeTo(200 - 1300 / 24 - 120 / 24, 0.2));
      expect(b.sacSource, SacSource.measured);
      expect(b.sacLitersPerMin, closeTo(20.0, 0.05));
      // Deco tank untouched so far: its series starts after the switch.
      expect(b.pressureSourceFor('deco50'), PressureSource.measured);
      expect(b.pressureFor('deco50'), closeTo(200.0, 1e-9));
    });

    test('no series: estimated linear pressure and dive-average SAC', () {
      final dive = squareDive(withPressures: false);
      final r = _request(dive, branchSeconds: 900);
      final actual = _analyze(r);
      final schedule = TankSchedule.fromDive(
        tanks: r.tanks,
        switches: r.gasSwitches,
      );
      final b = buildBranchState(
        request: r,
        actual: actual,
        schedule: schedule,
        branchIndex: branchIndexFor(r.timestamps, 900),
      );
      expect(b.pressureSourceFor('back'), PressureSource.estimated);
      final p = b.pressureFor('back')!;
      expect(p, lessThan(200));
      expect(p, greaterThan(80));
      expect(b.sacSource, SacSource.diveAverage);
      expect(b.sacLitersPerMin, greaterThan(0));
    });

    test('no pressures at all: unknown pressure, log-average then default', () {
      final dive = squareDive(withPressures: false);
      const bare = DiveTank(
        id: 'back',
        volume: 24,
        gasMix: GasMix(o2: 21),
        role: TankRole.backGas,
      );
      final r1 = _request(dive, tanks: const [bare], fallbackSacLpm: 17.5);
      final a1 = _analyze(r1);
      final s1 = TankSchedule.fromDive(tanks: r1.tanks, switches: const []);
      final b1 = buildBranchState(
        request: r1,
        actual: a1,
        schedule: s1,
        branchIndex: 30,
      );
      expect(b1.pressureSourceFor('back'), PressureSource.unknown);
      expect(b1.pressureFor('back'), isNull);
      expect(b1.sacSource, SacSource.logAverage);
      expect(b1.sacLitersPerMin, 17.5);

      final r2 = _request(dive, tanks: const [bare]);
      final b2 = buildBranchState(
        request: r2,
        actual: _analyze(r2),
        schedule: s1,
        branchIndex: 30,
      );
      expect(b2.sacSource, SacSource.defaultValue);
      expect(b2.sacLitersPerMin, const ScenarioSettings().defaultSacLpm);
    });
  });
}
