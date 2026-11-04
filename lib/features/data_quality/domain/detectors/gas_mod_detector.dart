import 'package:collection/collection.dart';

import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

/// Flags recorded gas/depth combinations that contradict physics or
/// procedure: the recorded mix or the recorded switch depth is wrong.
/// OC only -- CCR/SCR loop ppO2 is setpoint-controlled, and gauge mode has
/// no trustworthy gas data.
class GasModDetector extends QualityDetector {
  const GasModDetector();

  @override
  String get id => 'gas_mod';

  /// 4: the ppO2 and hypoxic findings record `hePercent`, so their message
  /// names a trimix as such (issue #4209). Findings stored by version 3 lack
  /// it; the bump raises the rescan banner that rewrites them.
  @override
  int get version => 4;
  @override
  QualityCategory get category => QualityCategory.gas;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    if (ctx.dive.diveMode != DiveMode.oc) return const [];
    final tanks = ctx.tanks;
    if (tanks.isEmpty) return const [];
    final out = <QualityFinding>[];
    final environment = ctx.dive.environment;

    // Bars relative to the diver's own maximum ppO2: warn once the recorded
    // gas/depth passes their ceiling, critical when it is well past it. The
    // margin is the constants' own gap (0.2), so a diver on the default 1.6
    // ceiling keeps exactly the historical 1.6 / 1.8 behaviour.
    final ppO2WarnBar = ctx.ppO2MaxBar;
    final ppO2CriticalBar =
        ppO2WarnBar +
        (QualityThresholds.ppO2CriticalBar - QualityThresholds.ppO2WarnBar);
    final ordered = [...tanks]..sort((a, b) => a.order.compareTo(b.order));

    domain.DiveTank? tankById(String tid) =>
        tanks.firstWhereOrNull((t) => t.id == tid);

    domain.GasMix mixAt(int t) {
      var active = ordered.first;
      for (final sw in ctx.gasSwitches) {
        if (sw.timestamp <= t) {
          active = tankById(sw.tankId) ?? active;
        } else {
          break;
        }
      }
      return active.gasMix;
    }

    // Sustained ppO2 above limits.
    int? runStart;
    var peak = 0.0;
    double? depthAtPeak;
    var runMix = const domain.GasMix(o2: 0);
    var lastT = 0;
    void closePpo2Run() {
      if (runStart != null &&
          lastT - runStart! >= QualityThresholds.ppO2SustainSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'ppo2:${runStart! ~/ 60}',
            severity: peak >= ppO2CriticalBar
                ? QualitySeverity.critical
                : QualitySeverity.warning,
            params: {
              'peakPpO2': peak,
              'o2Percent': runMix.o2,
              'hePercent': runMix.he,
              'depthAtPeak': depthAtPeak,
              'startSeconds': runStart,
              'durationSeconds': lastT - runStart!,
            },
          ),
        );
      }
      runStart = null;
      peak = 0;
    }

    for (final p in ctx.primarySamples) {
      final mix = mixAt(p.t);
      final ppo2 = mix.o2 / 100.0 * environment.pressureAtDepth(p.depth);
      if (ppo2 > ppO2WarnBar) {
        runStart ??= p.t;
        if (ppo2 > peak) {
          peak = ppo2;
          depthAtPeak = p.depth;
          runMix = mix;
        }
        lastT = p.t;
      } else {
        closePpo2Run();
      }
    }
    closePpo2Run();

    // Hypoxic mix breathed at the surface.
    int? hypoStart;
    var hypoLastT = 0;
    var hypoMix = const domain.GasMix(o2: 100);
    void closeHypoRun() {
      if (hypoStart != null &&
          hypoLastT - hypoStart! >= QualityThresholds.hypoxicSustainSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'hypoxic:${hypoStart! ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'o2Percent': hypoMix.o2,
              'hePercent': hypoMix.he,
              'startSeconds': hypoStart,
              'durationSeconds': hypoLastT - hypoStart!,
            },
          ),
        );
      }
      hypoStart = null;
    }

    for (final p in ctx.primarySamples) {
      final mix = mixAt(p.t);
      if (mix.o2 / 100.0 < QualityThresholds.hypoxicFo2 &&
          p.depth < QualityThresholds.hypoxicMaxDepthMeters) {
        hypoStart ??= p.t;
        hypoMix = mix;
        hypoLastT = p.t;
      } else {
        closeHypoRun();
      }
    }
    closeHypoRun();

    // Switches recorded deeper than the target gas's MOD.
    for (final sw in ctx.gasSwitches) {
      final tank = tankById(sw.tankId);
      final d = sw.depth;
      if (tank == null || d == null) continue;
      final fo2 = tank.gasMix.o2 / 100.0;
      if (fo2 <= 0) continue;
      final mod = maxOperatingDepthMeters(
        fo2,
        maxPpO2: ppO2WarnBar,
        environment: environment,
      );
      if (d > mod + QualityThresholds.modToleranceMeters) {
        out.add(
          make(
            ctx,
            discriminator: 'switchmod:${sw.id}',
            severity: QualitySeverity.warning,
            params: {
              'switchDepth': d,
              'modMeters': mod,
              'o2Percent': tank.gasMix.o2,
            },
          ),
        );
      }
    }
    return out;
  }
}
