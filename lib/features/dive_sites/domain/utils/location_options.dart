/// Case-/whitespace-insensitive key two location strings are considered the
/// same location under. Internal runs of whitespace are collapsed as well as
/// the ends trimmed, so "New  Zealand" (a stray double space) keys the same
/// as "New Zealand".
String locationDedupKey(String value) =>
    _normalizeWhitespace(value).toLowerCase();

String _normalizeWhitespace(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// The distinct, sorted labels among [values], collapsing entries that share
/// a [locationDedupKey].
///
/// Country and region are free text (issue #1373), so the same place can be
/// recorded as "Egypt", "egypt" and " EGYPT " across different sites; showing
/// all three as separate dropdown options would be confusing. Null and blank
/// values are dropped. Among variants that share a key, the most frequent one
/// is kept as the label - a single mistyped variant should not outrank the
/// spelling most of the diver's sites actually use. Remaining ties prefer
/// ordinary capitalization, then code-unit order, so the choice never depends
/// on the order sites happen to load in.
List<String> distinctLocationLabels(Iterable<String?> values) {
  final countsByKey = <String, Map<String, int>>{};
  for (final raw in values) {
    if (raw == null) continue;
    final normalized = _normalizeWhitespace(raw);
    if (normalized.isEmpty) continue;
    final counts = countsByKey.putIfAbsent(normalized.toLowerCase(), () => {});
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }
  final labels = countsByKey.values.map(_canonicalLabel).toList()..sort();
  return labels;
}

/// Picks the best label among [variantCounts] (each raw spelling mapped to
/// how many sites use it) for one [locationDedupKey].
String _canonicalLabel(Map<String, int> variantCounts) {
  var best = variantCounts.keys.first;
  var bestCount = variantCounts[best]!;
  var bestScore = _lowerCaseTailScore(best);
  for (final entry in variantCounts.entries.skip(1)) {
    final variant = entry.key;
    final count = entry.value;
    final score = _lowerCaseTailScore(variant);
    final better =
        count > bestCount ||
        (count == bestCount &&
            (score > bestScore ||
                (score == bestScore && variant.compareTo(best) < 0)));
    if (better) {
      best = variant;
      bestCount = count;
      bestScore = score;
    }
  }
  return best;
}

/// Count of lowercase letters after the first character, e.g. 4 for "Egypt"
/// and 0 for "EGYPT". Used only to break a tie between equally frequent
/// variants - plain code-unit comparison cannot do this on its own, since
/// ASCII uppercase letters sort before lowercase ones and would otherwise
/// make "EGYPT" "smaller" than "Egypt".
int _lowerCaseTailScore(String value) {
  if (value.length <= 1) return 0;
  var score = 0;
  for (final rune in value.substring(1).runes) {
    final char = String.fromCharCode(rune);
    if (char == char.toLowerCase() && char != char.toUpperCase()) score++;
  }
  return score;
}
