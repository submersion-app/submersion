import 'dart:math' as math;

import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';
import 'package:submersion/core/deco/gas_switch/on_time_gas_schedule.dart';
import 'package:submersion/core/deco/gas_switch/tissue_replay.dart';

/// Gas-switch efficiency of an open-circuit dive (issue #2939): late and
/// missed deco gas switches against the same ideal ascent TTS assumes, each
/// costed by tissue replay. Read-only: it runs on its own engines.
class GasSwitchEfficiencyAnalyzer {
  GasSwitchEfficiencyAnalyzer({
    required this.newEngine,
    required this.gases,
    required this.maxPpO2,
    this.startCompartments,
  });

  /// A switch this long after the ideal time is late, whatever the depth.
  static const int timeToleranceSeconds = 120;

  final BuhlmannAlgorithm Function() newEngine;
  final List<AvailableGas> gases;
  final double maxPpO2;
  final List<TissueCompartment>? startCompartments;

  /// Null when not applicable (fewer than two gases, no samples, or a
  /// ceiling or TTS curve that does not match the profile). [ttsCurve] is the
  /// analysis' own TTS per sample: the as-dived side of every comparison, so
  /// the dive is not replayed again for it.
  GasSwitchEfficiency? analyze({
    required List<double> depths,
    required List<int> timestamps,
    required List<ProfileGasSegment> gasSegments,
    required List<double> ceilingCurve,
    required List<int> ttsCurve,
  }) {
    if (gases.length < 2 ||
        depths.length < 2 ||
        gasSegments.isEmpty ||
        ceilingCurve.length != depths.length ||
        ttsCurve.length != depths.length) {
      return null;
    }
    if (!ceilingCurve.any((c) => c > 0)) {
      return GasSwitchEfficiency.notEvaluated;
    }
    final detection = detectSwitchWindows(
      depths: depths,
      timestamps: timestamps,
      gasSegments: gasSegments,
      gases: gases,
      maxPpO2: maxPpO2,
    );
    if (detection.assessedGasCount == 0) {
      return GasSwitchEfficiency.notEvaluated;
    }

    final stopIncrement = newEngine().stopIncrement;
    final flagged = [
      for (final w in detection.windows)
        if (_hadObligation(w, ceilingCurve) &&
            _isFault(w, depths, timestamps, stopIncrement))
          w,
    ];
    if (flagged.isEmpty) return const GasSwitchEfficiency(evaluated: true);

    final replay = TissueReplay(
      newEngine: newEngine,
      depths: depths,
      timestamps: timestamps,
      ascentPlan: OptimalOcAscentGas(gases: gases, maxPpO2: maxPpO2),
      startCompartments: startCompartments,
    );
    final windows = [
      for (final w in flagged)
        _toWindow(
          w,
          depths,
          timestamps,
          replay.peakTtsGap(
            actualTts: ttsCurve,
            counterfactual: withSwitchesOnTime(gasSegments, [w], timestamps),
            fromIndex: w.startIndex,
            mustEvaluateIndex: w.endIndex,
          ),
        ),
    ];
    final total = flagged.length == 1
        ? windows.single.extraDecoSeconds
        : replay.peakTtsGap(
            actualTts: ttsCurve,
            counterfactual: withSwitchesOnTime(
              gasSegments,
              flagged,
              timestamps,
            ),
            fromIndex: flagged.first.startIndex,
          );
    return GasSwitchEfficiency(
      evaluated: true,
      windows: windows,
      totalExtraDecoSeconds: total,
    );
  }

  bool _hadObligation(DetectedSwitchWindow w, List<double> ceilingCurve) {
    for (var k = w.startIndex; k <= w.endIndex; k++) {
      if (ceilingCurve[k] > 0) return true;
    }
    return false;
  }

  bool _isFault(
    DetectedSwitchWindow w,
    List<double> depths,
    List<int> timestamps,
    double stopIncrement,
  ) {
    final switchIndex = w.switchIndex;
    if (switchIndex == null) return true;
    final depthDelay = _idealDepth(w, depths) - depths[switchIndex];
    final timeDelay = timestamps[switchIndex] - timestamps[w.startIndex];
    return depthDelay > stopIncrement + 1e-9 ||
        timeDelay > timeToleranceSeconds;
  }

  double _idealDepth(DetectedSwitchWindow w, List<double> depths) =>
      math.min(w.gas.maxPpO2Mod, depths[w.startIndex]);

  GasSwitchWindow _toWindow(
    DetectedSwitchWindow w,
    List<double> depths,
    List<int> timestamps,
    int extraDecoSeconds,
  ) {
    final switchIndex = w.switchIndex;
    final idealTimestamp = timestamps[w.startIndex];
    final idealDepth = _idealDepth(w, depths);
    final endTimestamp = timestamps[w.endIndex];
    final switchTimestamp = switchIndex == null
        ? null
        : timestamps[switchIndex];
    return GasSwitchWindow(
      kind: switchIndex == null
          ? GasSwitchWindowKind.missed
          : GasSwitchWindowKind.late,
      fO2: w.gas.fO2,
      fHe: w.gas.fHe,
      idealTimestamp: idealTimestamp,
      idealDepth: idealDepth,
      switchTimestamp: switchTimestamp,
      switchDepth: switchIndex == null ? null : depths[switchIndex],
      endTimestamp: endTimestamp,
      delaySeconds: (switchTimestamp ?? endTimestamp) - idealTimestamp,
      depthDelayMeters: switchIndex == null
          ? null
          : idealDepth - depths[switchIndex],
      extraDecoSeconds: extraDecoSeconds,
    );
  }
}
