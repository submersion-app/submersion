import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

/// Reuses the file-import DiveMatcher so the inbox and the import wizard can
/// never disagree about what counts as a duplicate.
class DuplicateDetector extends QualityDetector {
  const DuplicateDetector();

  static const _matcher = DiveMatcher();

  @override
  String get id => 'duplicate';
  @override
  int get version => 2;
  @override
  QualityCategory get category => QualityCategory.duplicate;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final dive = ctx.dive;
    final entry = dive.effectiveEntryTime;
    final maxDepth = dive.maxDepth;
    final duration = dive.effectiveRuntime?.inSeconds;
    if (maxDepth == null || duration == null || duration <= 0) {
      return const [];
    }
    final serial = dive.diveComputerSerial;
    final out = <QualityFinding>[];
    for (final n in ctx.neighbors) {
      final nDepth = n.maxDepth;
      final nDuration = n.durationSeconds;
      if (nDepth == null || nDuration == null || nDuration <= 0) continue;
      if (entry.difference(n.entryTime).abs() >
          QualityThresholds.duplicateWindow) {
        continue;
      }
      final score = _matcher.calculateMatchScore(
        wearableStartTime: entry,
        wearableMaxDepth: maxDepth,
        wearableDurationSeconds: duration,
        existingStartTime: n.entryTime,
        existingMaxDepth: nDepth,
        existingDurationSeconds: nDuration,
      );
      if (!_matcher.isPossibleDuplicate(score)) continue;
      out.add(
        makePair(
          ctx,
          otherDiveId: n.id,
          severity: _matcher.isProbableDuplicate(score)
              ? QualitySeverity.critical
              : QualitySeverity.warning,
          params: {
            'score': score,
            'timeDiffMinutes': entry.difference(n.entryTime).inMinutes.abs(),
            'thisMaxDepth': maxDepth,
            'otherMaxDepth': nDepth,
            // Two records from one physical computer are a re-download, not
            // a second computer's view of the dive, and
            // DiveConsolidationBuilder refuses to merge them. Recorded here
            // so the inbox can withhold a Consolidate button that could only
            // ever fail. An unknown serial on either side stays false: the
            // pair may well be consolidatable, and the service is the one
            // that decides.
            'sameComputer':
                serial != null &&
                serial.isNotEmpty &&
                serial == n.computerSerial,
          },
        ),
      );
    }
    return out;
  }
}
