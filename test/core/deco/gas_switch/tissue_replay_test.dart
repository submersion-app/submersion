import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';
import 'package:submersion/core/deco/gas_switch/on_time_gas_schedule.dart';
import 'package:submersion/core/deco/gas_switch/tissue_replay.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final gases = [gasOf(0.21), gasOf(0.5), gasOf(1.0)];
  final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);
  BuhlmannAlgorithm newEngine() => BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7);

  TissueReplay replay({List<TissueCompartment>? startCompartments}) =>
      TissueReplay(
        newEngine: newEngine,
        depths: dive.depths,
        timestamps: dive.timestamps,
        ascentPlan: plan,
        startCompartments: startCompartments,
      );

  void expectSameTissues(BuhlmannAlgorithm a, List<TissueCompartment> b) {
    for (var k = 0; k < b.length; k++) {
      expect(a.compartments[k].currentPN2, closeTo(b[k].currentPN2, 1e-12));
      expect(a.compartments[k].currentPHe, closeTo(b[k].currentPHe, 1e-12));
    }
  }

  test('replay loads tissues exactly like the analysis engine', () {
    final segments = [seg(0, 0.21), seg(1695, 0.5), seg(2545, 1.0)];
    final statuses = newEngine().processProfileWithGasSegments(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: segments,
      ascentGasPlan: plan,
    );
    final replayed = replay().replayThrough(segments, dive.depths.length - 1);
    expectSameTissues(replayed, statuses.last.compartments);
  });

  test('replay seeds residual tissues like the analysis', () {
    final residual =
        (newEngine()..calculateSegment(depthMeters: 30, durationSeconds: 1800))
            .compartments;
    final segments = [seg(0, 0.21), seg(1695, 0.5)];
    final engine = newEngine()..setCompartments(residual);
    final statuses = engine.processProfileWithGasSegments(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: segments,
      ascentGasPlan: plan,
    );
    final replayed = replay(
      startCompartments: residual,
    ).replayThrough(segments, dive.depths.length - 1);
    expectSameTissues(replayed, statuses.last.compartments);
  });

  test('the analysis TTS curve stands in for replaying the dive as dived', () {
    final recorded = [seg(0, 0.21), seg(1910, 0.5)];
    final start = indexAt(dive, 1630);
    final end = indexAt(dive, 1910);
    final counterfactual = withSwitchesOnTime(recorded, [
      DetectedSwitchWindow(
        gas: gases[1],
        startIndex: start,
        endIndex: end,
        switchIndex: end,
      ),
    ], dive.timestamps);
    final ttsCurve = newEngine()
        .processProfileWithGasSegments(
          depths: dive.depths,
          timestamps: dive.timestamps,
          gasSegments: recorded,
          ascentGasPlan: plan,
        )
        .map((s) => s.ttsSeconds)
        .toList();

    final replayed = replay().peakTtsGap(
      actual: recorded,
      counterfactual: counterfactual,
      fromIndex: start,
      mustEvaluateIndex: end,
    );
    final fromCurve = replay().peakTtsGap(
      actualTts: ttsCurve,
      counterfactual: counterfactual,
      fromIndex: start,
      mustEvaluateIndex: end,
    );
    expect(replayed, greaterThan(0));
    expect(fromCurve, replayed);
  });

  test('identical schedules have no gap', () {
    final segments = [seg(0, 0.21), seg(1690, 0.5)];
    expect(
      replay().peakTtsGap(
        actual: segments,
        counterfactual: segments,
        fromIndex: indexAt(dive, 1630),
      ),
      0,
    );
  });

  test('a late EAN50 switch costs deco, a missed one costs more', () {
    final start = indexAt(dive, 1630);
    int costOf(
      List<ProfileGasSegment> recorded,
      int endIndex,
      int? switchIndex,
    ) {
      final window = DetectedSwitchWindow(
        gas: gases[1],
        startIndex: start,
        endIndex: endIndex,
        switchIndex: switchIndex,
      );
      return replay().peakTtsGap(
        actual: recorded,
        counterfactual: withSwitchesOnTime(recorded, [window], dive.timestamps),
        fromIndex: start,
        mustEvaluateIndex: endIndex,
      );
    }

    final lateCost = costOf(
      [seg(0, 0.21), seg(1910, 0.5)],
      indexAt(dive, 1910),
      indexAt(dive, 1910),
    );
    final missedCost = costOf([seg(0, 0.21)], dive.depths.length - 1, null);
    expect(lateCost, greaterThan(0));
    expect(missedCost, greaterThan(lateCost));
  });
}
