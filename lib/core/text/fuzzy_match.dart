/// Pure text-similarity helpers for suggestion and near-duplicate detection.
///
/// No Flutter imports — unit-testable in isolation.
library;

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

List<String> _bigrams(String s) {
  final result = <String>[];
  for (var i = 0; i < s.length - 1; i++) {
    result.add(s.substring(i, i + 2));
  }
  return result;
}

/// Sørensen-Dice coefficient over character bigrams of the normalized inputs.
///
/// Returns 0.0 (no similarity) to 1.0 (identical). Inputs shorter than two
/// characters fall back to normalized equality.
double diceCoefficient(String a, String b) {
  final na = normalize(a);
  final nb = normalize(b);
  if (na == nb) return 1.0;
  if (na.length < 2 || nb.length < 2) return 0.0;

  final bigramsA = _bigrams(na);
  final bigramsB = _bigrams(nb);
  final used = List<bool>.filled(bigramsB.length, false);

  var intersection = 0;
  for (final bigram in bigramsA) {
    for (var i = 0; i < bigramsB.length; i++) {
      if (!used[i] && bigramsB[i] == bigram) {
        used[i] = true;
        intersection++;
        break;
      }
    }
  }
  return (2.0 * intersection) / (bigramsA.length + bigramsB.length);
}

/// Returns the candidate most similar to [input] whose Dice score is at or
/// above [threshold], or null if none qualify. Ties resolve to the
/// earliest-listed candidate.
String? findSimilar(
  String input,
  Iterable<String> candidates, {
  double threshold = 0.7,
}) {
  String? best;
  var bestScore = threshold;
  for (final candidate in candidates) {
    final score = diceCoefficient(input, candidate);
    if (score >= bestScore && (best == null || score > bestScore)) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}
