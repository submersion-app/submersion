import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';

/// Finds dives one file holds twice (#3110).
///
/// A logbook can carry the same dive twice: a DiveMate logbook seen for this
/// work had 186 of its 545 dives in pairs, a manual entry beside the same
/// dive downloaded later, with different dive numbers. The multi-file batch
/// pass in `ImportDuplicateChecker` matches loosely because two files of one
/// trip overlap; within one file that would flag genuine back-to-back dives,
/// so a pair here needs the same start minute and a near-perfect score
/// (depth and duration inside the matcher's full-credit bands). Profiles are
/// not compared: the copies' samples differ in 83 of those 186 pairs.
///
/// Of each pair, the copy carrying less data is the one flagged, pointing at
/// the other through [DiveMatchResult.inBatchIndex], so the review's default
/// (skip the flagged row) keeps the fuller copy. On a tie the later row is
/// flagged, as the batch pass does.
abstract final class WithinFileDiveDuplicates {
  /// The score a same-minute pair must reach.
  static const double minScore = 0.95;

  /// Flagged dive index to its match, for [dives] in payload order.
  static Map<int, DiveMatchResult> find(
    List<Map<String, dynamic>> dives,
    DiveMatcher matcher,
  ) {
    final matches = <int, DiveMatchResult>{};
    // Indexes already in a pair, either side. A dive pairs at most once.
    final paired = <int>{};

    for (var i = 1; i < dives.length; i++) {
      final at = dives[i]['dateTime'] as DateTime?;
      if (at == null) continue;
      for (var j = 0; j < i; j++) {
        if (paired.contains(j)) continue;
        final otherAt = dives[j]['dateTime'] as DateTime?;
        if (otherAt == null) continue;
        final gap = at.difference(otherAt).abs();
        if (gap >= const Duration(minutes: 1)) continue;
        final score = matcher.calculateMatchScore(
          wearableStartTime: at,
          wearableMaxDepth: _depth(dives[i]),
          wearableDurationSeconds: _seconds(dives[i]),
          existingStartTime: otherAt,
          existingMaxDepth: _depth(dives[j]),
          existingDurationSeconds: _seconds(dives[j]),
        );
        if (score < minScore) continue;

        final flagJ = richness(dives[j]) < richness(dives[i]);
        final flagged = flagJ ? j : i;
        final kept = flagJ ? i : j;
        matches[flagged] = DiveMatchResult(
          diveId: '',
          inBatchIndex: kept,
          score: score,
          timeDifferenceMs: gap.inMilliseconds,
        );
        paired.addAll({i, j});
        break;
      }
    }
    return matches;
  }

  /// How much a dive map carries beyond its time, depth and duration, so the
  /// fuller of two copies can be kept.
  static int richness(Map<String, dynamic> dive) {
    var score = 0;
    for (final key in _detailKeys) {
      final value = dive[key];
      if (value == null) continue;
      if (value is Iterable && value.isEmpty) continue;
      if (value is String && value.trim().isEmpty) continue;
      score++;
    }
    return score;
  }

  static const _detailKeys = [
    'site',
    'buddyRefs',
    'diveGuideRefs',
    'notes',
    'equipmentRefs',
    'diveTypeIds',
    'tanks',
    'profile',
    'rating',
    'visibility',
    'visibilityMeters',
    'currentStrength',
    'waterType',
    'diveCenterRef',
    'tripRef',
    'sightings',
  ];

  static double _depth(Map<String, dynamic> dive) =>
      (dive['maxDepth'] as num?)?.toDouble() ?? 0;

  static int _seconds(Map<String, dynamic> dive) =>
      ((dive['runtime'] as Duration?) ?? (dive['duration'] as Duration?))
          ?.inSeconds ??
      0;
}
