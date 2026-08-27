import 'dart:math' as math;

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/repairs/repair_predicates.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class DepthSpikeDetector extends QualityDetector {
  const DepthSpikeDetector();

  @override
  String get id => 'depth_spike';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final s = ctx.primarySamples;

    var spikes = 0;
    for (
      var i = 1;
      i + 1 < s.length && spikes < QualityThresholds.maxSpikeFindingsPerDive;
      i++
    ) {
      final dt1 = s[i].t - s[i - 1].t;
      // Shares its definition with ProfileRepairService.despike so the
      // offered repair clears exactly what is flagged here.
      if (RepairPredicates.isDepthSpike(
        dt1: dt1,
        dt2: s[i + 1].t - s[i].t,
        d0: s[i - 1].depth,
        d1: s[i].depth,
        d2: s[i + 1].depth,
      )) {
        final r1 = (s[i].depth - s[i - 1].depth) / dt1;
        spikes++;
        out.add(
          make(
            ctx,
            discriminator: 'spike:${s[i].t ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'atSeconds': s[i].t,
              'depth': s[i].depth,
              'impliedRateMetersPerSecond': r1.abs(),
            },
          ),
        );
      }
    }

    final negative = [
      for (final p in s)
        if (p.depth < QualityThresholds.negativeDepthMeters) p.depth,
    ];
    if (negative.isNotEmpty) {
      out.add(
        make(
          ctx,
          discriminator: 'negative',
          severity: QualitySeverity.warning,
          params: {
            'sampleCount': negative.length,
            'minDepth': negative.reduce(math.min),
          },
        ),
      );
    }

    final storedMax = ctx.dive.maxDepth;
    if (s.isNotEmpty && storedMax != null) {
      final profileMax = s.map((p) => p.depth).reduce(math.max);
      final tol = math.max(
        QualityThresholds.maxDepthMismatchMinMeters,
        profileMax * QualityThresholds.maxDepthMismatchFraction,
      );
      if ((storedMax - profileMax).abs() > tol) {
        out.add(
          make(
            ctx,
            discriminator: 'maxdepth',
            severity: QualitySeverity.warning,
            params: {
              'storedMaxDepth': storedMax,
              'profileMaxDepth': profileMax,
            },
          ),
        );
      }
    }
    return out;
  }
}
