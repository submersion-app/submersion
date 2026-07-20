import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

/// A computer that surfaced briefly logs one physical dive as two. Signature:
/// same serial, tiny surface interval, and the boundary looks like a
/// continuation.
class SplitPairDetector extends QualityDetector {
  const SplitPairDetector();

  @override
  String get id => 'split_pair';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.duplicate;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final dive = ctx.dive;
    final serial = dive.diveComputerSerial;
    if (serial == null || serial.isEmpty) return const [];
    final entry = dive.effectiveEntryTime;
    final runtime = dive.effectiveRuntime;
    if (runtime == null) return const [];
    final exit = entry.add(runtime);
    final firstDepth = ctx.primarySamples.isNotEmpty
        ? ctx.primarySamples.first.depth
        : null;
    final lastDepth = ctx.primarySamples.isNotEmpty
        ? ctx.primarySamples.last.depth
        : null;

    final out = <QualityFinding>[];
    for (final n in ctx.neighbors) {
      if (n.computerSerial != serial) continue;
      final thisFirst = !entry.isAfter(n.entryTime);
      final Duration? gap;
      if (thisFirst) {
        gap = n.entryTime.difference(exit);
      } else if (n.exitTime != null) {
        gap = entry.difference(n.exitTime!);
      } else {
        gap = null;
      }
      if (gap == null ||
          gap.isNegative ||
          gap > QualityThresholds.splitMaxGap) {
        continue;
      }
      final earlierEndsDeep = thisFirst
          ? (lastDepth != null &&
                lastDepth > QualityThresholds.splitDeepEndMeters)
          : (n.lastSampleDepth != null &&
                n.lastSampleDepth! > QualityThresholds.splitDeepEndMeters);
      final laterStartsDeep = thisFirst
          ? (n.firstSampleDepth != null &&
                n.firstSampleDepth! > QualityThresholds.splitDeepEndMeters)
          : (firstDepth != null &&
                firstDepth > QualityThresholds.splitDeepEndMeters);
      final continuation =
          earlierEndsDeep ||
          laterStartsDeep ||
          gap <= QualityThresholds.splitShallowGap;
      if (!continuation) continue;
      out.add(
        makePair(
          ctx,
          otherDiveId: n.id,
          severity: QualitySeverity.warning,
          params: {
            'gapSeconds': gap.inSeconds,
            'earlierEndsDeep': earlierEndsDeep,
            'laterStartsDeep': laterStartsDeep,
          },
        ),
      );
    }
    return out;
  }
}
