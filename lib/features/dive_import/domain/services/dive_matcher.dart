/// Service for matching imported dives to existing dive log entries.
///
/// Uses fuzzy matching based on time, depth, and duration to detect
/// potential duplicates when importing from external sources.
class DiveMatcher {
  /// Creates a [DiveMatcher] instance.
  const DiveMatcher();

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
    final timeScore = _calculateTimeScore(wearableStartTime, existingStartTime);

    // Time is a NECESSARY condition, not just a weighted term.
    // `_calculateTimeScore` is 0.0 once the two starts are >= 15 min apart;
    // with no time evidence, a depth + duration coincidence (0.30 + 0.20 =
    // 0.50) must not be able to reach the possible-duplicate threshold. Two
    // recordings that do not line up in time cannot be the same physical dive.
    if (timeScore <= 0) return 0.0;

    final depthScore = _calculateDepthScore(wearableMaxDepth, existingMaxDepth);
    final durationScore = _calculateDurationScore(
      wearableDurationSeconds,
      existingDurationSeconds,
    );

    // Weighted composite score
    return (timeScore * 0.50) + (depthScore * 0.30) + (durationScore * 0.20);
  }

  /// Calculate time score: within 5 min = 100%, 15 min = 0%
  double _calculateTimeScore(DateTime wearableTime, DateTime existingTime) {
    final timeDiff = wearableTime.difference(existingTime).abs();
    final timeMinutes = timeDiff.inMinutes;

    if (timeMinutes <= 5) {
      return 1.0;
    } else if (timeMinutes >= 15) {
      return 0.0;
    } else {
      return 1.0 - ((timeMinutes - 5) / 10);
    }
  }

  /// Calculate depth score: within 10% = 100%, 20%+ diff = 0%
  double _calculateDepthScore(double wearableDepth, double existingDepth) {
    if (existingDepth <= 0) {
      // Handle edge case of zero or negative depth
      return 0.0;
    }

    final depthDiff = (wearableDepth - existingDepth).abs();
    final depthPercent = depthDiff / existingDepth;

    if (depthPercent <= 0.10) {
      return 1.0;
    } else if (depthPercent >= 0.20) {
      return 0.0;
    } else {
      return 1.0 - ((depthPercent - 0.10) / 0.10);
    }
  }

  /// Calculate duration score: within 3 min = 100%, 10 min = 0%
  double _calculateDurationScore(
    int wearableDurationSeconds,
    int existingDurationSeconds,
  ) {
    final durationDiff = (wearableDurationSeconds - existingDurationSeconds)
        .abs();
    final durationDiffMinutes = durationDiff / 60;

    if (durationDiffMinutes <= 3) {
      return 1.0;
    } else if (durationDiffMinutes >= 10) {
      return 0.0;
    } else {
      return 1.0 - ((durationDiffMinutes - 3) / 7);
    }
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

  const DiveMatchResult({
    required this.diveId,
    required this.score,
    required this.timeDifferenceMs,
    this.depthDifferenceMeters,
    this.durationDifferenceSeconds,
    this.siteName,
    this.matchedComputerId,
    this.matchedExistingSource = false,
  });

  /// Returns true if this is a probable duplicate (score >= 0.7).
  bool get isProbable => score >= 0.7;

  /// Returns true if this is a possible duplicate (score >= 0.5).
  bool get isPossible => score >= 0.5;
}
