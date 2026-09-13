/// The comparison key for a person's name: trimmed, inner whitespace
/// collapsed, and lowercased with Dart's Unicode-aware [String.toLowerCase].
/// Matching happens in Dart on this key because SQLite's `LOWER` folds only
/// ASCII, so `ÉRIC` would never match `éric` in SQL.
String legacyNameKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Splits the legacy free-text `dives.buddy` and `dives.dive_master` values
/// into individual names so they can become buddy records (#1831).
///
/// Separators are `, ; / & +`, newlines, the full-width comma and the
/// ideographic comma, plus the standalone words in [_conjunctions]. Nothing
/// inside `(...)` or `[...]` is split, so `Joe (Customer)` stays one name.
/// Placeholders such as `None` are dropped, so a text holding only a
/// placeholder parses to no names at all, which is how the Buddies card
/// tells a real text buddy from a solo dive.
abstract final class LegacyNameParser {
  static const Set<String> _separators = {
    ',',
    ';',
    '/',
    '&',
    '+',
    '\n',
    '，',
    '、',
  };

  /// Conjunctions for the app's Latin-script locales. One splits a part only
  /// when that part has more than one word, so a lone name survives. Words
  /// match case-insensitively; the single letters `e` and `y` split only
  /// when written in lowercase, because a capital one (`John E Smith`) is a
  /// middle initial.
  static const Set<String> _conjunctions = {'and', 'und', 'et', 'en', 'és'};
  static const Set<String> _letterConjunctions = {'e', 'y'};

  static const Set<String> _placeholders = {
    'none',
    'solo',
    'n/a',
    'na',
    '-',
    '--',
    'nobody',
    'no buddy',
    'keine',
    'aucun',
    'ninguno',
    'nessuno',
    'nenhum',
    'geen',
  };

  /// `n/a` as a whole token. Outside brackets it splits like a separator,
  /// because `/` is itself a separator and would otherwise leave the names
  /// `N` and `A`. Inside brackets it is kept, like everything else there, so
  /// `Joe (N/A)` stays one name.
  static final RegExp _notApplicable = RegExp(
    r'(?<!\p{L})n/a(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _whitespace = RegExp(r'\s+');

  /// The distinct names in [text], in first-seen order.
  static List<String> parse(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final names = <String>[];
    final seen = <String>{};
    for (final part in _splitOnSeparators(normalized)) {
      for (final piece in _splitOnConjunctions(part)) {
        final name = piece.trim().replaceAll(_whitespace, ' ');
        final key = legacyNameKey(name);
        if (key.isEmpty ||
            _placeholders.contains(key) ||
            !_letter.hasMatch(name)) {
          continue;
        }
        if (seen.add(key)) names.add(name);
      }
    }
    return List.unmodifiable(names);
  }

  /// Splits [text] on [_separators] and on `n/a`, both only at bracket
  /// depth zero. Walks UTF-16 code units so the `n/a` match offsets line up;
  /// every separator and bracket is a single code unit.
  static List<String> _splitOnSeparators(String text) {
    final notApplicableEnds = {
      for (final match in _notApplicable.allMatches(text))
        match.start: match.end,
    };
    final parts = <String>[];
    var start = 0;
    var depth = 0;
    var i = 0;
    while (i < text.length) {
      final char = text[i];
      final notApplicableEnd = notApplicableEnds[i];
      if (depth == 0 &&
          (notApplicableEnd != null || _separators.contains(char))) {
        parts.add(text.substring(start, i));
        i = notApplicableEnd ?? i + 1;
        start = i;
        continue;
      }
      depth = _depthAfter(depth, char);
      i++;
    }
    parts.add(text.substring(start));
    return parts;
  }

  static List<String> _splitOnConjunctions(String part) {
    final words = part.trim().split(_whitespace);
    if (words.length < 2) return [part];
    final pieces = <String>[];
    var current = <String>[];
    var depth = 0;
    for (final word in words) {
      if (depth == 0 && _isConjunction(word)) {
        pieces.add(current.join(' '));
        current = <String>[];
      } else {
        current = [...current, word];
      }
      depth = _depthAfter(depth, word);
    }
    pieces.add(current.join(' '));
    return pieces;
  }

  static bool _isConjunction(String word) =>
      _letterConjunctions.contains(word) ||
      _conjunctions.contains(word.toLowerCase());

  /// Bracket depth after reading [text], starting from [depth]. A stray
  /// closing bracket never takes it below zero.
  static int _depthAfter(int depth, String text) {
    var result = depth;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char == '(' || char == '[') {
        result++;
      } else if ((char == ')' || char == ']') && result > 0) {
        result--;
      }
    }
    return result;
  }
}
