import 'dart:math' as math;

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class SampleGapDetector extends QualityDetector {
  const SampleGapDetector();

  @override
  String get id => 'sample_gap';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final s = ctx.primarySamples;
    if (s.length < 3) return const [];
    final intervals = <int>[
      for (var i = 1; i < s.length; i++)
        if (s[i].t > s[i - 1].t) s[i].t - s[i - 1].t,
    ];
    if (intervals.isEmpty) return const [];
    final sorted = [...intervals]..sort();
    final median = sorted[sorted.length ~/ 2];
    final threshold = math.max(
      median * QualityThresholds.gapMedianFactor,
      QualityThresholds.gapMinSeconds.toDouble(),
    );
    var gapCount = 0;
    var totalGap = 0;
    var longest = 0;
    for (final iv in intervals) {
      if (iv > threshold) {
        gapCount++;
        totalGap += iv;
        longest = math.max(longest, iv);
      }
    }
    if (gapCount == 0) return const [];
    final runtimeSec = s.last.t - s.first.t;
    final severity =
        runtimeSec > 0 &&
            totalGap > runtimeSec * QualityThresholds.gapWarnFractionOfRuntime
        ? QualitySeverity.warning
        : QualitySeverity.info;
    return [
      make(
        ctx,
        severity: severity,
        params: {
          'gapCount': gapCount,
          'totalGapSeconds': totalGap,
          'longestGapSeconds': longest,
          'medianIntervalSeconds': median,
        },
      ),
    ];
  }
}
