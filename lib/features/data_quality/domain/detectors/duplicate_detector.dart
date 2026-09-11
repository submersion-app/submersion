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
  int get version => 4;
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
      final sameComputer =
          serial != null && serial.isNotEmpty && serial == n.computerSerial;
      // Stored runtime, else stored bottom time: the same two columns the
      // neighbor query reads. Not `duration` (effectiveRuntime), which falls
      // back to exit minus entry and then to the profile; the pair's two
      // contexts would then disagree on one dive's duration and the choice
      // would depend on scan order.
      final storedDuration = (dive.runtime ?? dive.bottomTime)?.inSeconds;
      final redundant = sameComputer
          ? redundantDuplicate(
              a: (
                id: dive.id,
                sampleCount: ctx.primarySampleCount,
                durationSeconds: storedDuration,
                maxDepth: maxDepth,
                carriesDiverData: ctx.carriesDiverData,
              ),
              b: (
                id: n.id,
                sampleCount: n.sampleCount,
                durationSeconds: nDuration,
                maxDepth: nDepth,
                carriesDiverData: n.carriesDiverData,
              ),
            )
          : null;
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
            'sameComputer': sameComputer,
            // The copy a same-computer re-download can lose without losing
            // data. Absent when neither side clearly dominates (an exact
            // tie, a mixed pair, or an unknown metric) and when the dominated
            // copy carries the diver's own entries (#1720), so the card falls
            // back to its no-automatic-fix row and the diver decides.
            'redundantDiveId': ?redundant,
          },
        ),
      );
    }
    return out;
  }
}

/// One side of a same-computer duplicate pair: the metrics that say how much
/// of the dive it recorded, plus whether the diver has written anything of
/// their own onto it.
typedef DuplicateRecording = ({
  String id,
  int? sampleCount,
  int? durationSeconds,
  double? maxDepth,
  bool? carriesDiverData,
});

/// The dive a same-computer re-download can delete without losing data, or
/// null when the choice is not clear-cut.
///
/// The survivor must be at least as rich on every metric (samples, runtime,
/// max depth) and strictly richer on one. An exact tie names nobody: two
/// identical downloads may each carry the diver's notes or site, and that is
/// their call. A metric missing on either side is unknown, not zero; it
/// blocks the choice rather than volunteering a dive on a fact nobody
/// recorded. Symmetric in its arguments, which matters because the pair has
/// one canonical finding written by whichever side the scan reached last.
///
/// Recording richness is not the whole story, which is what issue #1720
/// reported: a diver had logged gear onto an older download and the fresh
/// re-download recorded more samples, so the poorer RECORDING was the richer
/// LOG and deleting it threw the diver's work away. A copy the diver has
/// written on is therefore never named, however little of the dive it
/// recorded -- the same reasoning the exact tie already applies, which is
/// that a copy holding the diver's own entries is theirs to judge. Unknown
/// blocks the choice here too: this decision deletes a dive, so "nobody
/// checked" must not read as "nothing to lose".
String? redundantDuplicate({
  required DuplicateRecording a,
  required DuplicateRecording b,
}) {
  final aSamples = a.sampleCount;
  final bSamples = b.sampleCount;
  final aDuration = a.durationSeconds;
  final bDuration = b.durationSeconds;
  final aDepth = a.maxDepth;
  final bDepth = b.maxDepth;
  if (aSamples == null ||
      bSamples == null ||
      aDuration == null ||
      bDuration == null ||
      aDepth == null ||
      bDepth == null) {
    return null;
  }
  final comparisons = [
    aSamples.compareTo(bSamples),
    aDuration.compareTo(bDuration),
    aDepth.compareTo(bDepth),
  ];
  if (comparisons.every((c) => c <= 0) && comparisons.any((c) => c < 0)) {
    return _losslessToDelete(a);
  }
  if (comparisons.every((c) => c >= 0) && comparisons.any((c) => c > 0)) {
    return _losslessToDelete(b);
  }
  return null;
}

/// [doomed]'s id when nothing of the diver's would go with it, else null.
/// Applied to the dominated side only: the survivor keeps whatever it holds,
/// so its own entries are never a reason to withhold the repair.
String? _losslessToDelete(DuplicateRecording doomed) =>
    doomed.carriesDiverData == false ? doomed.id : null;
