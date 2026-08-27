import 'dart:math' as math;

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/repairs/repair_predicates.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

/// Sustained vertical rates beyond real diving indicate corrupt samples --
/// distinct from the ascent-rate SAFETY events, which cap out at rates a
/// diver can actually produce.
class ImpossibleRateDetector extends QualityDetector {
  const ImpossibleRateDetector();

  @override
  String get id => 'impossible_rate';
  @override
  int get version => 2;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final s = ctx.primarySamples;
    final out = <QualityFinding>[];
    int? runStartIndex;
    var runMaxRate = 0.0;
    var lastIndex = 0;

    void closeRun() {
      if (runStartIndex != null) {
        final start = s[runStartIndex!];
        final end = s[lastIndex];
        if (end.t - start.t >= QualityThresholds.impossibleRateMinSeconds) {
          out.add(
            make(
              ctx,
              discriminator: 'run:${start.t ~/ 60}',
              severity: QualitySeverity.warning,
              params: {
                'startSeconds': start.t,
                'durationSeconds': end.t - start.t,
                'maxRateMetersPerMinute': runMaxRate,
                // Whether redrawing the run's interior as a straight line
                // between its endpoints leaves a plausible rate. Oscillating
                // garbage does; a sustained fast descent does not, and gets
                // no one-tap repair.
                'interpolatable':
                    RepairPredicates.impossibleRunIsInterpolatable(
                      sampleCount: lastIndex - runStartIndex! + 1,
                      startSeconds: start.t,
                      endSeconds: end.t,
                      startDepth: start.depth,
                      endDepth: end.depth,
                    ),
              },
            ),
          );
        }
      }
      runStartIndex = null;
      runMaxRate = 0;
    }

    for (var i = 1; i < s.length; i++) {
      final dt = s[i].t - s[i - 1].t;
      if (dt <= 0) continue;
      final ratePerMin = ((s[i].depth - s[i - 1].depth) / dt * 60).abs();
      if (ratePerMin > QualityThresholds.impossibleRateMetersPerMinute) {
        runStartIndex ??= i - 1;
        runMaxRate = math.max(runMaxRate, ratePerMin);
        lastIndex = i;
      } else {
        closeRun();
      }
    }
    closeRun();
    return out;
  }
}
