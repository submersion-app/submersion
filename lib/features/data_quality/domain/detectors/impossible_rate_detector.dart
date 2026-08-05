import 'dart:math' as math;

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

/// Sustained vertical rates beyond real diving indicate corrupt samples --
/// distinct from the ascent-rate SAFETY events, which cap out at rates a
/// diver can actually produce.
class ImpossibleRateDetector extends QualityDetector {
  const ImpossibleRateDetector();

  @override
  String get id => 'impossible_rate';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final s = ctx.primarySamples;
    final out = <QualityFinding>[];
    int? runStart;
    var runMaxRate = 0.0;
    var lastT = 0;

    void closeRun() {
      if (runStart != null &&
          lastT - runStart! >= QualityThresholds.impossibleRateMinSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'run:${runStart! ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'startSeconds': runStart,
              'durationSeconds': lastT - runStart!,
              'maxRateMetersPerMinute': runMaxRate,
            },
          ),
        );
      }
      runStart = null;
      runMaxRate = 0;
    }

    for (var i = 1; i < s.length; i++) {
      final dt = s[i].t - s[i - 1].t;
      if (dt <= 0) continue;
      final ratePerMin = ((s[i].depth - s[i - 1].depth) / dt * 60).abs();
      if (ratePerMin > QualityThresholds.impossibleRateMetersPerMinute) {
        runStart ??= s[i - 1].t;
        runMaxRate = math.max(runMaxRate, ratePerMin);
        lastT = s[i].t;
      } else {
        closeRun();
      }
    }
    closeRun();
    return out;
  }
}
