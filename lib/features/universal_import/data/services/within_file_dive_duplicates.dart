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
/// Copies of one dive form a cluster: every dive matched to any member
/// belongs to it, so three copies are one cluster, not a pair and a
/// leftover. The copy carrying the most data is kept and every other copy is
/// flagged, pointing at it through [DiveMatchResult.inBatchIndex], so the
/// review's default (skip the flagged rows) keeps the fullest copy. On a tie
/// the earliest row is kept, as the batch pass keeps the earlier dive.
abstract final class WithinFileDiveDuplicates {
  /// The score a pair starting under a minute apart must reach.
  static const double minScore = 0.95;

  /// Flagged dive index to its match, for [dives] in payload order.
  static Map<int, DiveMatchResult> find(
    List<Map<String, dynamic>> dives,
    DiveMatcher matcher,
  ) {
    // Union-find over the matching pairs, so clusters join transitively.
    final parent = <int, int>{};
    int root(int i) {
      var r = i;
      while (parent[r] != null && parent[r] != r) {
        r = parent[r]!;
      }
      return r;
    }

    for (final MapEntry(key: i, value: earlier) in _earlierWithinAMinute(
      dives,
    ).entries) {
      for (final j in earlier) {
        if (!_isSameDive(dives[i], dives[j], matcher)) continue;
        final ri = root(i);
        final rj = root(j);
        if (ri != rj) parent[ri > rj ? ri : rj] = ri < rj ? ri : rj;
      }
    }

    final clusters = <int, List<int>>{};
    for (final i in parent.keys.toSet()..addAll(parent.values)) {
      (clusters[root(i)] ??= []).add(i);
    }

    final matches = <int, DiveMatchResult>{};
    for (final members in clusters.values) {
      if (members.length < 2) continue;
      members.sort();
      var kept = members.first;
      for (final m in members) {
        if (richness(dives[m]) > richness(dives[kept])) kept = m;
      }
      final keptAt = dives[kept]['dateTime'] as DateTime;
      for (final m in members) {
        if (m == kept) continue;
        final at = dives[m]['dateTime'] as DateTime;
        matches[m] = DiveMatchResult(
          diveId: '',
          inBatchIndex: kept,
          score: _score(dives[m], dives[kept], matcher),
          timeDifferenceMs: at.difference(keptAt).inMilliseconds.abs(),
        );
      }
    }
    return matches;
  }

  static bool _isSameDive(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    DiveMatcher matcher,
  ) => _score(a, b, matcher) >= minScore;

  static double _score(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    DiveMatcher matcher,
  ) => matcher.calculateMatchScore(
    wearableStartTime: a['dateTime'] as DateTime,
    wearableMaxDepth: _depth(a),
    wearableDurationSeconds: _seconds(a),
    existingStartTime: b['dateTime'] as DateTime,
    existingMaxDepth: _depth(b),
    existingDurationSeconds: _seconds(b),
  );

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
