import 'dart:math';

import 'package:submersion/core/text/fuzzy_match.dart';

/// Up to five candidates for a mistyped name, best first.
///
/// Scored by the better of two measures: Dice similarity over bigrams (the
/// site resolver's measure, good for a shared stem) and a normalized
/// Damerau-Levenshtein distance (good for a transposition like `nmae`,
/// which shares no bigram with `name`). A prefix match always ranks, so a
/// partial word while typing still suggests.
List<String> suggestNames(String typed, Iterable<String> candidates) {
  final t = typed.toLowerCase();
  final scored = <(String, double)>[];
  for (final c in candidates) {
    final lower = c.toLowerCase();
    final double score;
    if (lower.startsWith(t) && t.isNotEmpty) {
      score = 1.0;
    } else {
      final maxLen = max(t.length, lower.length);
      final edit = maxLen == 0
          ? 0.0
          : 1 - _damerauLevenshtein(t, lower) / maxLen;
      score = max(diceCoefficient(t, lower), edit);
    }
    if (score >= 0.5) scored.add((c, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored.take(5)) s.$1];
}

/// Optimal string alignment distance: insert, delete, substitute, and the
/// transposition of two adjacent characters each cost one.
int _damerauLevenshtein(String a, String b) {
  final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      d[i][j] = min(
        min(d[i - 1][j] + 1, d[i][j - 1] + 1),
        d[i - 1][j - 1] + cost,
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[a.length][b.length];
}
