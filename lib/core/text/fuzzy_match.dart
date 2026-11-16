/// Pure text-similarity helpers for suggestion and near-duplicate detection.
///
/// No Flutter imports — unit-testable in isolation.
library;

import 'dart:typed_data';

/// Accented and other non-ASCII lowercase Latin letters mapped to the ASCII
/// spelling a diver types without them: Latin-1, Latin Extended-A, and the
/// Romanian comma-below letters (#4498). Letters with no single base letter
/// spell out (ß as "ss", æ as "ae", þ as "th"). Only lowercase forms appear:
/// [foldForSearch] lowercases first.
const Map<int, String> _diacriticMap = {
  // Latin-1 Supplement.
  0xDF: 'ss', // ß
  0xE0: 'a', // à
  0xE1: 'a', // á
  0xE2: 'a', // â
  0xE3: 'a', // ã
  0xE4: 'a', // ä
  0xE5: 'a', // å
  0xE6: 'ae', // æ
  0xE7: 'c', // ç
  0xE8: 'e', // è
  0xE9: 'e', // é
  0xEA: 'e', // ê
  0xEB: 'e', // ë
  0xEC: 'i', // ì
  0xED: 'i', // í
  0xEE: 'i', // î
  0xEF: 'i', // ï
  0xF0: 'd', // ð
  0xF1: 'n', // ñ
  0xF2: 'o', // ò
  0xF3: 'o', // ó
  0xF4: 'o', // ô
  0xF5: 'o', // õ
  0xF6: 'o', // ö
  0xF8: 'o', // ø
  0xF9: 'u', // ù
  0xFA: 'u', // ú
  0xFB: 'u', // û
  0xFC: 'u', // ü
  0xFD: 'y', // ý
  0xFE: 'th', // þ
  0xFF: 'y', // ÿ
  // Latin Extended-A.
  0x101: 'a', // ā
  0x103: 'a', // ă
  0x105: 'a', // ą
  0x107: 'c', // ć
  0x109: 'c', // ĉ
  0x10B: 'c', // ċ
  0x10D: 'c', // č
  0x10F: 'd', // ď
  0x111: 'd', // đ
  0x113: 'e', // ē
  0x115: 'e', // ĕ
  0x117: 'e', // ė
  0x119: 'e', // ę
  0x11B: 'e', // ě
  0x11D: 'g', // ĝ
  0x11F: 'g', // ğ
  0x121: 'g', // ġ
  0x123: 'g', // ģ
  0x125: 'h', // ĥ
  0x127: 'h', // ħ
  0x129: 'i', // ĩ
  0x12B: 'i', // ī
  0x12D: 'i', // ĭ
  0x12F: 'i', // į
  0x131: 'i', // ı
  0x133: 'ij', // ĳ
  0x135: 'j', // ĵ
  0x137: 'k', // ķ
  0x138: 'k', // ĸ
  0x13A: 'l', // ĺ
  0x13C: 'l', // ļ
  0x13E: 'l', // ľ
  0x140: 'l', // ŀ
  0x142: 'l', // ł
  0x144: 'n', // ń
  0x146: 'n', // ņ
  0x148: 'n', // ň
  0x149: 'n', // ŉ
  0x14B: 'n', // ŋ
  0x14D: 'o', // ō
  0x14F: 'o', // ŏ
  0x151: 'o', // ő
  0x153: 'oe', // œ
  0x155: 'r', // ŕ
  0x157: 'r', // ŗ
  0x159: 'r', // ř
  0x15B: 's', // ś
  0x15D: 's', // ŝ
  0x15F: 's', // ş
  0x161: 's', // š
  0x163: 't', // ţ
  0x165: 't', // ť
  0x167: 't', // ŧ
  0x169: 'u', // ũ
  0x16B: 'u', // ū
  0x16D: 'u', // ŭ
  0x16F: 'u', // ů
  0x171: 'u', // ű
  0x173: 'u', // ų
  0x175: 'w', // ŵ
  0x177: 'y', // ŷ
  0x17A: 'z', // ź
  0x17C: 'z', // ż
  0x17E: 'z', // ž
  0x17F: 's', // ſ
  // Latin Extended-B: Romanian s and t with comma below.
  0x219: 's', // ș
  0x21B: 't', // ț
};

/// The lowest code unit [_diacriticMap] or [_isCombiningAccent] can act on.
/// Text made only of code units below it folds by [String.toLowerCase] alone.
const _firstFoldable = 0xC0;

/// The combining accents written after a Latin, Greek or Cyrillic letter
/// (U+0300 to U+036F). Decomposed text carries "e" and a separate acute
/// where composed text carries "é", and `toLowerCase` turns "İ" into "i"
/// and a combining dot; without the mark both agree with the plain letter.
bool _isCombiningAccent(int rune) => rune >= 0x300 && rune <= 0x36F;

/// [input] lowercased with common accents stripped, so "Jérémie" and
/// "jeremie" compare equal (#4498). Unlike [normalize] it keeps surrounding
/// whitespace, so it can fold a search needle and the column it is matched
/// against (the `search_fold` SQL function) the same way.
///
/// Runs once per row and column a search reads, so plain ASCII text, the
/// common case, returns from `toLowerCase` without walking its runes.
String foldForSearch(String input) {
  final lower = input.toLowerCase();
  var first = 0;
  while (first < lower.length && lower.codeUnitAt(first) < _firstFoldable) {
    first++;
  }
  if (first == lower.length) return lower;
  final buffer = StringBuffer(lower.substring(0, first));
  for (final rune in lower.substring(first).runes) {
    if (_isCombiningAccent(rune)) continue;
    buffer.write(_diacriticMap[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// Normalizes [input] for comparison: trims, lowercases, and strips common
/// diacritics so "Cancún" and "cancun" compare equal.
String normalize(String input) => foldForSearch(input.trim());

/// The longest bigram list worth sorting by hand: pasted text can be far
/// longer than any name, and insertion sort is quadratic.
const _maxInsertionSorted = 32;

/// Each adjacent pair of code units packed into one integer, sorted. Names
/// are short and this runs once per name, so the usual case skips the
/// comparator calls of [List.sort], which cost more than the sorting.
Uint32List _bigrams(String s) {
  if (s.length < 2) return Uint32List(0);
  final result = Uint32List(s.length - 1);
  for (var i = 0; i < result.length; i++) {
    result[i] = s.codeUnitAt(i) << 16 | s.codeUnitAt(i + 1);
  }
  if (result.length > _maxInsertionSorted) return result..sort();
  for (var i = 1; i < result.length; i++) {
    final pair = result[i];
    var at = i;
    while (at > 0 && result[at - 1] > pair) {
      result[at] = result[at - 1];
      at--;
    }
    result[at] = pair;
  }
  return result;
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
