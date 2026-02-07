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

  const DiveMatchResult({
    required this.diveId,
    required this.score,
    required this.timeDifferenceMs,
    this.depthDifferenceMeters,
    this.durationDifferenceSeconds,
  });

  /// Returns true if this is a probable duplicate (score >= 0.7).
  bool get isProbable => score >= 0.7;

  /// Returns true if this is a possible duplicate (score >= 0.5).
  bool get isPossible => score >= 0.5;
}
