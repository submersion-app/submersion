import 'package:submersion/core/matching/match_scorer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Service for matching imported dives to existing dive log entries.
///
/// Uses fuzzy matching based on time, depth, and duration to detect
/// potential duplicates when importing from external sources.
class DiveMatcher {
  /// Creates a [DiveMatcher] instance.
  const DiveMatcher();

  /// Minutes apart at which the time score, and so the whole score, is zero.
  static const _timeZeroMinutes = 15;

  /// The gap between two dives' starts at which the score reaches zero, so a
  /// pair this far apart or more is not worth scoring at all (see
  /// [MatchScorer.gateOnZeroTime]).
  static const candidateWindow = Duration(minutes: _timeZeroMinutes);

  /// Weighted scorer for file imports: time 50%, depth 30%, duration 20%.
  ///
  /// Time is scored over 5-15 min (whole minutes), depth as a percentage
  /// (10%-20%), and duration over 3-10 min; a zero time score gates the whole
  /// match to 0.0 (see [MatchScorer.gateOnZeroTime]).
  static const _scorer = MatchScorer(
    timeWeight: 0.50,
    depthWeight: 0.30,
    durationWeight: 0.20,
    timeFull: 5, // minutes
    timeZero: _timeZeroMinutes * 1.0,
    depthFull: 0.10, // fraction
    depthZero: 0.20,
    durationFull: 3, // minutes
    durationZero: 10,
    gateOnZeroTime: true,
  );

  /// Calculate a match score between an imported dive and an existing dive.
  ///
  /// Returns a score from 0.0 (no match) to 1.0 (perfect match).
  ///
  /// Scoring weights:
  /// - Time proximity: 50% (most important)
  /// - Depth similarity: 30%
  /// - Duration similarity: 20%
  double calculateMatchScore({
    required DateTime wearableStartTime,
    required double wearableMaxDepth,
    required int wearableDurationSeconds,
    required DateTime existingStartTime,
    required double existingMaxDepth,
    required int existingDurationSeconds,
  }) {
    final timeMinutes = wearableStartTime
        .difference(existingStartTime)
        .abs()
        .inMinutes
        .toDouble();
    // Percent depth difference. A non-positive existing depth is treated as
    // maximally different (infinity -> depth score 0), preserving the previous
    // zero/negative-depth guard.
    final depthValue = existingMaxDepth <= 0
        ? double.infinity
        : (wearableMaxDepth - existingMaxDepth).abs() / existingMaxDepth;
    final durationMinutes =
        (wearableDurationSeconds - existingDurationSeconds).abs() / 60.0;

    return _scorer.score(
      timeValue: timeMinutes,
      depthValue: depthValue,
      durationValue: durationMinutes,
    );
  }

  /// Check if the score indicates a probable duplicate (high confidence).
  ///
  /// A score >= 0.7 indicates the dives are very likely the same dive.
  bool isProbableDuplicate(double score) => score >= 0.7;

  /// Check if the score indicates a possible duplicate (medium confidence).
  ///
  /// A score >= 0.5 indicates the dives might be the same dive and
  /// should be reviewed by the user.
  bool isPossibleDuplicate(double score) => score >= 0.5;
}

/// Result of matching an imported dive against an existing dive.
/// Which kind of dive waiting for its readings a download fills.
enum FillTargetKind { plan, draft }

/// The plan or draft a download fills (issue #637).
class FillTarget {
  const FillTarget({required this.diveId, required this.kind});

  /// The target for [dive]'s flags: a dive with both reads as the draft.
  factory FillTarget.of(Dive dive) => FillTarget(
    diveId: dive.id,
    kind: dive.isDraft ? FillTargetKind.draft : FillTargetKind.plan,
  );

  final String diveId;
  final FillTargetKind kind;

  @override
  bool operator ==(Object other) =>
      other is FillTarget && other.diveId == diveId && other.kind == kind;

  @override
  int get hashCode => Object.hash(diveId, kind);
}

class DiveMatchResult {
  /// The ID of the matched existing dive.
  final String diveId;

  /// The match score from 0.0 (no match) to 1.0 (perfect match).
  final double score;

  /// Time difference between the dives in milliseconds.
  final int timeDifferenceMs;

  /// Depth difference between the dives in meters (optional).
  final double? depthDifferenceMeters;

  /// Duration difference between the dives in seconds (optional).
  final int? durationDifferenceSeconds;

  /// Site name of the matched existing dive (for display in review UI).
  final String? siteName;

  /// The matched existing dive's `computerId`, when known.
  ///
  /// Used by the import wizard to auto-suggest consolidation only for
  /// cross-computer matches (a re-download from the SAME computer should
  /// never be auto-suggested for consolidation — that's a plain duplicate).
  final String? matchedComputerId;

  /// True when [diveId] is confidently the SAME data the diver already has,
  /// not a fuzzy score match: either an exact hit against one of the
  /// matched dive's EXISTING `dive_data_sources` keys (fingerprint or
  /// source UUID) — see `DiveRepository.getSourceKeysByDiveId` — or, for a
  /// live dive-computer download, a contained-segment match (timestamp
  /// containment plus depth-curve agreement showing the download natively
  /// re-records part of a dive already stored; see
  /// `DiveImportService._detectContainedSegment`).
  ///
  /// This means the downloaded dive's data is ALREADY present on [diveId]
  /// as a source (primary or previously-consolidated secondary); it is a
  /// re-download, not a new source. The import wizard must default this to
  /// [DuplicateAction.skip] and must never auto-default (or offer as a
  /// bulk/manual consolidate target) [DuplicateAction.consolidate] for such
  /// a match, regardless of [matchedComputerId] or [score].
  final bool matchedExistingSource;

  /// When non-null, this match is against ANOTHER DIVE IN THE SAME IMPORT
  /// BATCH (the dive at this payload index), not an existing database dive.
  /// [diveId] is empty for such matches. In-batch duplicates default to
  /// skip and are never eligible for consolidation (there is no existing
  /// dive to fold into).
  final int? inBatchIndex;

  /// When non-null, [diveId] is a dive waiting for its readings that this
  /// download fills: a plan on the download's local day or the day before
  /// (issues #2002 and #4003), or a draft whose taps the download overlaps
  /// (issue #637). The wizard defaults such a row to
  /// [DuplicateAction.fillPlanned]: the target keeps its human-entered facts
  /// and the download supplies the measured ones. Never set together with
  /// [matchedExistingSource] or [inBatchIndex]; the fill pass runs only for
  /// otherwise unmatched downloads.
  final FillTarget? fillTarget;

  const DiveMatchResult({
    required this.diveId,
    required this.score,
    required this.timeDifferenceMs,
    this.depthDifferenceMeters,
    this.durationDifferenceSeconds,
    this.siteName,
    this.matchedComputerId,
    this.matchedExistingSource = false,
    this.inBatchIndex,
    this.fillTarget,
  });

  /// True when this row fills a plan or draft rather than matching a logged
  /// dive.
  bool get isFill => fillTarget != null;

  /// Point the fill at another plan or draft. [diveId] follows the target so
  /// the comparison card and the wizard's existing-dive lookups need no
  /// extra plumbing.
  ///
  /// There is deliberately no way to clear the target here: an empty
  /// [diveId] already means "duplicate of another dive in this batch" to the
  /// comparison card, so a fill row that loses its target stops being a
  /// match at all (see ImportWizardNotifier.setPlannedFillTarget).
  DiveMatchResult withFillTarget(FillTarget target) {
    return DiveMatchResult(
      diveId: target.diveId,
      score: score,
      timeDifferenceMs: timeDifferenceMs,
      depthDifferenceMeters: depthDifferenceMeters,
      durationDifferenceSeconds: durationDifferenceSeconds,
      siteName: siteName,
      matchedComputerId: matchedComputerId,
      matchedExistingSource: matchedExistingSource,
      inBatchIndex: inBatchIndex,
      fillTarget: target,
    );
  }

  /// Returns true if this is a probable duplicate (score >= 0.7).
  bool get isProbable => score >= 0.7;

  /// Returns true if this is a possible duplicate (score >= 0.5).
  bool get isPossible => score >= 0.5;
}
