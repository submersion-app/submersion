import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';

/// Flags a secondary computer of a consolidated dive that sits out of step
/// with the primary: its depth trace matches the primary's at an offset other
/// than the stored one (#2894).
///
/// Consolidation used to place every overlapping computer by its entry time,
/// so a computer whose clock had drifted (about a second a day on some) put
/// its whole profile, pressures and events that far off. [ClockOffsetDetector]
/// catches only whole-hour differences, the unset-time-zone signature.
class SourceAlignmentDetector extends QualityDetector {
  const SourceAlignmentDetector();

  @override
  String get id => 'source_alignment';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.time;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    for (final check in ctx.sourceAlignments) {
      final disagreement = (check.fit.offsetSeconds - check.storedOffsetSeconds)
          .abs();
      if (!check.fit.isStrongMatch ||
          disagreement <= QualityThresholds.sourceAlignmentToleranceSeconds) {
        continue;
      }
      final source = ctx.sources
          .where((s) => s.id == check.sourceId)
          .firstOrNull;
      out.add(
        make(
          ctx,
          discriminator: 'src:${check.sourceId}',
          computerId: source?.computerId,
          severity: QualitySeverity.warning,
          params: {
            'sourceId': check.sourceId,
            'storedOffsetSeconds': check.storedOffsetSeconds,
            'fittedOffsetSeconds': check.fit.offsetSeconds,
          },
        ),
      );
    }
    return out;
  }
}
