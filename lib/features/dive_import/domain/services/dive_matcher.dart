import 'package:submersion/core/matching/match_scorer.dart';

/// Service for matching imported dives to existing dive log entries.
///
/// Uses fuzzy matching based on time, depth, and duration to detect
/// potential duplicates when importing from external sources.
class DiveMatcher {
  /// Creates a [DiveMatcher] instance.
  const DiveMatcher();

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
    timeZero: 15,
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

  /// True when [diveId] was matched via an exact hit against one of the
  /// matched dive's EXISTING `dive_data_sources` keys (fingerprint or
  /// source UUID) — see `DiveRepository.getSourceKeysByDiveId`.
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
  });

  /// Returns true if this is a probable duplicate (score >= 0.7).
  bool get isProbable => score >= 0.7;

  /// Returns true if this is a possible duplicate (score >= 0.5).
  bool get isPossible => score >= 0.5;
}
