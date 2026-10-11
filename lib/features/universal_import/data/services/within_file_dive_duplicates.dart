import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';

/// Finds dives one file holds twice (#3110).
///
/// A logbook can carry the same dive twice: a DiveMate logbook seen for this
/// work had 186 of its 545 dives in pairs, a manual entry beside the same
/// dive downloaded later, with different dive numbers. The multi-file batch
/// pass in `ImportDuplicateChecker` matches loosely because two files of one
/// trip overlap; within one file that would flag genuine back-to-back dives,
/// so a pair here must start less than a minute apart and reach a
/// near-perfect score (depth and duration inside the matcher's full-credit
/// bands). Elapsed time, not the clock minute: two dives cannot start
/// seconds apart, so copies at 10:15:59 and 10:16:00 are one dive logged
/// twice, which minute buckets would miss. Profiles are
/// not compared: the copies' samples differ in 83 of those 186 pairs.
///
/// Of each pair, the copy carrying less data is the one flagged, pointing at
/// the other through [DiveMatchResult.inBatchIndex], so the review's default
/// (skip the flagged row) keeps the fuller copy. On a tie the later row is
/// flagged, as the batch pass does. A third copy pairs with the copy already
/// kept and is flagged itself, so the kept copy never also becomes a flagged
/// one.
abstract final class WithinFileDiveDuplicates {
  /// The score a pair starting under a minute apart must reach.
  static const double minScore = 0.95;

  /// Flagged dive index to its match, for [dives] in payload order.
  static Map<int, DiveMatchResult> find(
    List<Map<String, dynamic>> dives,
    DiveMatcher matcher,
  ) {
    final matches = <int, DiveMatchResult>{};
    // A flagged dive pairs once; a kept one stays the target for any further
    // copy of the same dive.
    final flaggedSet = <int>{};
    final keptSet = <int>{};
    final near = _earlierWithinAMinute(dives);

    for (var i = 1; i < dives.length; i++) {
      final at = dives[i]['dateTime'] as DateTime?;
      final candidates = near[i];
      if (at == null || candidates == null) continue;
      if (keptSet.contains(i)) continue;
      for (final j in candidates) {
        if (flaggedSet.contains(j)) continue;
        final otherAt = dives[j]['dateTime'] as DateTime;
        final gap = at.difference(otherAt).abs();
        final score = matcher.calculateMatchScore(
          wearableStartTime: at,
          wearableMaxDepth: _depth(dives[i]),
          wearableDurationSeconds: _seconds(dives[i]),
          existingStartTime: otherAt,
          existingMaxDepth: _depth(dives[j]),
          existingDurationSeconds: _seconds(dives[j]),
        );
        if (score < minScore) continue;

        final flagJ =
            !keptSet.contains(j) && richness(dives[j]) < richness(dives[i]);
        final flagged = flagJ ? j : i;
        final kept = flagJ ? i : j;
        matches[flagged] = DiveMatchResult(
          diveId: '',
          inBatchIndex: kept,
          score: score,
          timeDifferenceMs: gap.inMilliseconds,
        );
        flaggedSet.add(flagged);
        keptSet.add(kept);
        break;
      }
    }
    return matches;
  }

  /// For each dive, the earlier rows (by payload order, ascending) that start
  /// less than a minute from it.
  ///
  /// Found with one sort and a sweep instead of comparing every pair: this
  /// pass runs on every single-file import, and a logbook of many thousand
  /// dives would otherwise cost tens of millions of comparisons.
  static Map<int, List<int>> _earlierWithinAMinute(
    List<Map<String, dynamic>> dives,
  ) {
    final timed = <(int, DateTime)>[
      for (var i = 0; i < dives.length; i++)
        if (dives[i]['dateTime'] case final DateTime at) (i, at),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final out = <int, List<int>>{};
    for (var a = 0; a < timed.length; a++) {
      for (var b = a + 1; b < timed.length; b++) {
        if (timed[b].$2.difference(timed[a].$2) >= const Duration(minutes: 1)) {
          break;
        }
        final (first, second) = timed[a].$1 < timed[b].$1
            ? (timed[a].$1, timed[b].$1)
            : (timed[b].$1, timed[a].$1);
        (out[second] ??= []).add(first);
      }
    }
    for (final list in out.values) {
      list.sort();
    }
    return out;
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
