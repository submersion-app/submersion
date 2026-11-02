import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/text/fuzzy_match.dart';

const _maxSuggestions = 5;

/// The score a name needs to be offered at all.
const _minScore = 0.5;

/// Up to five candidates for a mistyped name, best first; ties keep the order
/// of [candidates].
///
/// Scored by the better of two measures: Dice similarity over bigrams (the
/// site resolver's measure, good for a shared stem) and a normalized
/// Damerau-Levenshtein distance (good for a transposition like `nmae`,
/// which shares no bigram with `name`). A prefix match always ranks, so a
/// partial word while typing still suggests.
List<String> suggestNames(String typed, Iterable<String> candidates) =>
    NameSuggester(candidates).suggest(typed);

/// [suggestNames] over a list held ready to be asked again: the editor asks
/// on every edit of an unresolved name, on the UI isolate (#3849), so what a
/// candidate needs for scoring is worked out once, here, rather than on each
/// comparison.
class NameSuggester {
  NameSuggester(Iterable<String> candidates)
    : _candidates = [for (final c in candidates) _Candidate(c)];

  final List<_Candidate> _candidates;

  late final _rowWidth =
      _candidates.fold(0, (longest, c) => max(longest, c.lower.length)) + 1;

  List<String> suggest(String typed) {
    final t = typed.toLowerCase();
    final typedDice = DiceText(t);
    final rows = _DistanceRows(_rowWidth);
    final best = <(_Candidate, double)>[];
    for (final c in _candidates) {
      final full = best.length == _maxSuggestions;
      final bar = full ? best.last.$2 : _minScore;
      // Nothing scores above 1, and a tie stays behind what came first.
      if (full && bar == 1.0) break;
      final score = _score(t, typedDice, c, bar, rows);
      if (full ? score <= bar : score < bar) continue;
      if (full) best.removeLast();
      var at = best.length;
      while (at > 0 && best[at - 1].$2 < score) {
        at--;
      }
      best.insert(at, (c, score));
    }
    return [for (final b in best) b.$1.label];
  }

  /// The score of [c], exact whenever it reaches [bar]. Below that the name
  /// is not offered, so the distance gives up as soon as it cannot help.
  double _score(
    String t,
    DiceText typedDice,
    _Candidate c,
    double bar,
    _DistanceRows rows,
  ) {
    final lower = c.lower;
    if (lower.startsWith(t) && t.isNotEmpty) return 1.0;
    final dice = typedDice.similarity(c.dice);
    final maxLen = max(t.length, lower.length);
    if (maxLen == 0) return dice;
    final limit = ((1 - max(dice, bar)) * maxLen).ceil();
    return max(dice, 1 - _distanceWithin(limit, t, lower, rows) / maxLen);
  }
}

class _Candidate {
  _Candidate(String label) : this._(label, label.toLowerCase());

  _Candidate._(this.label, this.lower) : dice = DiceText(lower);

  final String label;
  final String lower;
  final DiceText dice;
}

/// The three rows of the distance table a comparison can reach, reused from
/// one comparison to the next within a [NameSuggester.suggest]. [width] fits
/// the longest candidate.
class _DistanceRows {
  _DistanceRows(int width)
    : twoBack = Int32List(width),
      oneBack = Int32List(width),
      current = Int32List(width);

  final Int32List twoBack;
  final Int32List oneBack;
  final Int32List current;
}

/// Optimal string alignment distance: insert, delete, substitute, and the
/// transposition of two adjacent characters each cost one. Only a result
/// within [limit] is exact: past it, this stops as soon as it can tell.
int _distanceWithin(int limit, String a, String b, _DistanceRows rows) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var twoBack = rows.twoBack;
  var oneBack = rows.oneBack;
  var current = rows.current;
  for (var j = 0; j <= b.length; j++) {
    oneBack[j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    final unitA = a.codeUnitAt(i - 1);
    current[0] = i;
    var currentMin = i;
    for (var j = 1; j <= b.length; j++) {
      final unitB = b.codeUnitAt(j - 1);
      var cell = min(
        min(oneBack[j] + 1, current[j - 1] + 1),
        oneBack[j - 1] + (unitA == unitB ? 0 : 1),
      );
      if (i > 1 &&
          j > 1 &&
          unitA == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == unitB) {
        cell = min(cell, twoBack[j - 2] + 1);
      }
      current[j] = cell;
      if (cell < currentMin) currentMin = cell;
    }
    // A row's minimum rises by at most one, so the row before this one is at
    // the limit or past it too, and a transposition from there costs one more:
    // no later row can come back within the limit.
    if (currentMin > limit) return limit + 1;
    final spare = twoBack;
    twoBack = oneBack;
    oneBack = current;
    current = spare;
  }
  return oneBack[b.length];
}
