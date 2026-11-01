/// Pure text-similarity helpers for suggestion and near-duplicate detection.
///
/// No Flutter imports — unit-testable in isolation.
library;

import 'dart:typed_data';

/// Common accented Latin code points mapped to their ASCII base letter.
const Map<int, String> _diacriticMap = {
  0xE0: 'a',
  0xE1: 'a',
  0xE2: 'a',
  0xE3: 'a',
  0xE4: 'a',
  0xE5: 'a',
  0xE7: 'c',
  0xE8: 'e',
  0xE9: 'e',
  0xEA: 'e',
  0xEB: 'e',
  0xEC: 'i',
  0xED: 'i',
  0xEE: 'i',
  0xEF: 'i',
  0xF1: 'n',
  0xF2: 'o',
  0xF3: 'o',
  0xF4: 'o',
  0xF5: 'o',
  0xF6: 'o',
  0xF8: 'o',
  0xF9: 'u',
  0xFA: 'u',
  0xFB: 'u',
  0xFC: 'u',
  0xFD: 'y',
  0xFF: 'y',
  // Hungarian double acute.
  0x151: 'o',
  0x171: 'u',
};

/// Normalizes [input] for comparison: trims, lowercases, and strips common
/// diacritics so "Cancún" and "cancun" compare equal.
String normalize(String input) {
  final lower = input.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    buffer.write(_diacriticMap[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// Each adjacent pair of code units packed into one integer, sorted.
Uint32List _bigrams(String s) {
  if (s.length < 2) return Uint32List(0);
  final result = Uint32List(s.length - 1);
  for (var i = 0; i < result.length; i++) {
    result[i] = s.codeUnitAt(i) << 16 | s.codeUnitAt(i + 1);
  }
  return result..sort();
}

/// A string made ready for Sørensen-Dice comparison: what
/// [diceCoefficient] otherwise works out for its inputs on every call, kept
/// so that a list compared again and again pays for it once.
class DiceText {
  factory DiceText(String input) {
    final normalized = normalize(input);
    return DiceText._(normalized, _bigrams(normalized));
  }

  DiceText._(this._normalized, this._pairs);

  final String _normalized;
  final Uint32List _pairs;

  /// The coefficient of this text and [other]; see [diceCoefficient]. Sorted
  /// bigrams intersect in one walk along both lists, a repeated bigram
  /// counting as many times as both sides have it.
  double similarity(DiceText other) {
    if (_normalized == other._normalized) return 1.0;
    if (_normalized.length < 2 || other._normalized.length < 2) return 0.0;

    final a = _pairs;
    final b = other._pairs;
    var i = 0;
    var j = 0;
    var intersection = 0;
    while (i < a.length && j < b.length) {
      final left = a[i];
      final right = b[j];
      if (left == right) {
        intersection++;
        i++;
        j++;
      } else if (left < right) {
        i++;
      } else {
        j++;
      }
    }
    return (2.0 * intersection) / (a.length + b.length);
  }
}

/// Sørensen-Dice coefficient over character bigrams of the normalized inputs.
///
/// Returns 0.0 (no similarity) to 1.0 (identical). Inputs shorter than two
/// characters fall back to normalized equality.
double diceCoefficient(String a, String b) =>
    DiceText(a).similarity(DiceText(b));

/// Returns the candidate most similar to [input] whose Dice score is at or
/// above [threshold], or null if none qualify. Ties resolve to the
/// earliest-listed candidate.
String? findSimilar(
  String input,
  Iterable<String> candidates, {
  double threshold = 0.7,
}) {
  final text = DiceText(input);
  String? best;
  var bestScore = threshold;
  for (final candidate in candidates) {
    final score = text.similarity(DiceText(candidate));
    if (score >= bestScore && (best == null || score > bestScore)) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}
