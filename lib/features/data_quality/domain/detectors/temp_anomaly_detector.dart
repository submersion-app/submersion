import 'dart:math' as math;

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class TempAnomalyDetector extends QualityDetector {
  const TempAnomalyDetector();

  @override
  String get id => 'temp_anomaly';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.temperature;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final temps = [
      for (final p in ctx.primarySamples)
        if (p.temp != null) (t: p.t, c: p.temp!),
    ];

    if (temps.isNotEmpty) {
      final minC = temps.map((e) => e.c).reduce(math.min);
      final maxC = temps.map((e) => e.c).reduce(math.max);
      if (minC < QualityThresholds.waterTempMinC ||
          maxC > QualityThresholds.waterTempMaxC) {
        out.add(
          make(
            ctx,
            discriminator: 'range',
            severity: QualitySeverity.warning,
            params: {
              'minTempC': minC,
              'maxTempC': maxC,
              // A Kelvin-scale reading (~273+) betrays the F-as-K firmware bug.
              'fahrenheitAsKelvinSuspected': maxC > 250,
            },
          ),
        );
      }
      var jumps = 0;
      for (
        var i = 1;
        i < temps.length &&
            jumps < QualityThresholds.maxTempJumpFindingsPerDive;
        i++
      ) {
        final dt = temps[i].t - temps[i - 1].t;
        if (dt <= 0 || dt > QualityThresholds.tempJumpMaxSampleGapSeconds) {
          continue;
        }
        final delta = (temps[i].c - temps[i - 1].c).abs();
        if (delta > QualityThresholds.tempJumpPerSampleC) {
          jumps++;
          out.add(
            make(
              ctx,
              discriminator: 'jump:${temps[i].t ~/ 300}',
              severity: QualitySeverity.warning,
              params: {'atSeconds': temps[i].t, 'deltaC': delta},
            ),
          );
        }
      }
    }

    final scalar = ctx.dive.waterTemp;
    if (scalar != null &&
        (scalar < QualityThresholds.waterTempMinC ||
            scalar > QualityThresholds.waterTempMaxC)) {
      out.add(
        make(
          ctx,
          discriminator: 'scalar',
          severity: QualitySeverity.warning,
          params: {'waterTempC': scalar},
        ),
      );
    }
    return out;
  }
}
