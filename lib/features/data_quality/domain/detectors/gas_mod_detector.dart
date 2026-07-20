import 'package:collection/collection.dart';

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
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.gas;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    if (ctx.dive.diveMode != DiveMode.oc) return const [];
    final tanks = ctx.tanks;
    if (tanks.isEmpty) return const [];
    final out = <QualityFinding>[];
    final ordered = [...tanks]..sort((a, b) => a.order.compareTo(b.order));

    domain.DiveTank? tankById(String tid) =>
        tanks.firstWhereOrNull((t) => t.id == tid);

    double fo2At(int t) {
      var active = ordered.first;
      for (final sw in ctx.gasSwitches) {
        if (sw.timestamp <= t) {
          active = tankById(sw.tankId) ?? active;
        } else {
          break;
        }
      }
      return active.gasMix.o2 / 100.0;
    }

    // Sustained ppO2 above limits.
    int? runStart;
    var peak = 0.0;
    double? depthAtPeak;
    var runFo2 = 0.0;
    var lastT = 0;
    void closePpo2Run() {
      if (runStart != null &&
          lastT - runStart! >= QualityThresholds.ppO2SustainSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'ppo2:${runStart! ~/ 60}',
            severity: peak >= QualityThresholds.ppO2CriticalBar
                ? QualitySeverity.critical
                : QualitySeverity.warning,
            params: {
              'peakPpO2': peak,
              'o2Percent': runFo2 * 100,
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
      final fo2 = fo2At(p.t);
      final ppo2 = fo2 * (p.depth / 10 + 1);
      if (ppo2 > QualityThresholds.ppO2WarnBar) {
        runStart ??= p.t;
        if (ppo2 > peak) {
          peak = ppo2;
          depthAtPeak = p.depth;
          runFo2 = fo2;
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
    var hypoFo2 = 1.0;
    void closeHypoRun() {
      if (hypoStart != null &&
          hypoLastT - hypoStart! >= QualityThresholds.hypoxicSustainSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'hypoxic:${hypoStart! ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'o2Percent': hypoFo2 * 100,
              'startSeconds': hypoStart,
              'durationSeconds': hypoLastT - hypoStart!,
            },
          ),
        );
      }
      hypoStart = null;
    }

    for (final p in ctx.primarySamples) {
      final fo2 = fo2At(p.t);
      if (fo2 < QualityThresholds.hypoxicFo2 &&
          p.depth < QualityThresholds.hypoxicMaxDepthMeters) {
        hypoStart ??= p.t;
        hypoFo2 = fo2;
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
      final mod = ((QualityThresholds.ppO2WarnBar / fo2) - 1) * 10;
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
