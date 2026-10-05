import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Word tokens the two texts may hold between them before the diff is
/// skipped. The LCS table is words(local) x words(remote) cells; at this
/// limit the worst case is 1000 x 1000 16-bit cells (2 MB).
const kWordDiffTokenLimit = 2000;

/// A run of one side's text. [unique] marks words that are not in the other
/// side. There is no common ancestor, so this means "only on this side",
/// never "added" or "removed".
@immutable
class DiffSpan {
  const DiffSpan(this.text, {required this.unique});

  final String text;
  final bool unique;

  @override
  bool operator ==(Object other) =>
      other is DiffSpan && other.text == text && other.unique == unique;

  @override
  int get hashCode => Object.hash(text, unique);

  @override
  String toString() => unique ? '[$text]' : text;
}

/// Both sides of a long-text conflict, split into marked and unmarked runs.
@immutable
class WordDiff {
  const WordDiff({required this.local, required this.remote});

  final List<DiffSpan> local;
  final List<DiffSpan> remote;

  /// False when the texts hold the same words and differ only in spacing.
  bool get hasUniqueWords =>
      local.any((s) => s.unique) || remote.any((s) => s.unique);
}

// CJK scripts are written without spaces, so each character is a word.
final _tokenPattern = RegExp(
  r"[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]"
  r"|\s+"
  r"|[\p{L}\p{N}\p{M}_']+"
  r"|[^\s\p{L}\p{N}\p{M}_']",
  unicode: true,
);

/// Splits [text] into words, whitespace runs and single punctuation marks.
/// Joining the result gives [text] back.
List<String> tokenizeForDiff(String text) => [
  for (final m in _tokenPattern.allMatches(text)) m[0]!,
];

bool _isSpace(String token) => token.trim().isEmpty;

/// Marks the words of each text that the other does not contain, using the
/// longest common subsequence of their word tokens. Whitespace is never
/// marked itself; a space between two marked words joins their highlight.
/// Returns null when the texts hold more than [kWordDiffTokenLimit] words.
WordDiff? diffWords(String local, String remote) {
  final a = tokenizeForDiff(local);
  final b = tokenizeForDiff(remote);
  final aw = [
    for (var i = 0; i < a.length; i++)
      if (!_isSpace(a[i])) i,
  ];
  final bw = [
    for (var i = 0; i < b.length; i++)
      if (!_isSpace(b[i])) i,
  ];
  if (aw.length + bw.length > kWordDiffTokenLimit) return null;

  final n = aw.length;
  final m = bw.length;
  final width = m + 1;
  // table[i][j] = LCS length of aw[i..] and bw[j..].
  final table = Uint16List((n + 1) * width);
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      final down = table[(i + 1) * width + j];
      final right = table[i * width + j + 1];
      table[i * width + j] = a[aw[i]] == b[bw[j]]
          ? table[(i + 1) * width + j + 1] + 1
          : (down >= right ? down : right);
    }
  }

  final aCommon = <int>{};
  final bCommon = <int>{};
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[aw[i]] == b[bw[j]]) {
      aCommon.add(aw[i]);
      bCommon.add(bw[j]);
      i++;
      j++;
    } else if (table[(i + 1) * width + j] >= table[i * width + j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  return WordDiff(local: _spans(a, aCommon), remote: _spans(b, bCommon));
}

List<DiffSpan> _spans(List<String> tokens, Set<int> common) {
  bool uniqueAt(int k) => !_isSpace(tokens[k]) && !common.contains(k);

  // A whitespace token is unique only when the words on both sides of it are,
  // so one highlight covers "two turtles" rather than two separate words.
  final flags = List<bool>.generate(tokens.length, (k) {
    if (!_isSpace(tokens[k])) return uniqueAt(k);
    return k > 0 && k < tokens.length - 1 && uniqueAt(k - 1) && uniqueAt(k + 1);
  });

  final spans = <DiffSpan>[];
  final buffer = StringBuffer();
  bool? current;
  for (var k = 0; k < tokens.length; k++) {
    if (current != null && flags[k] != current) {
      spans.add(DiffSpan(buffer.toString(), unique: current));
      buffer.clear();
    }
    current = flags[k];
    buffer.write(tokens[k]);
  }
  if (current != null) spans.add(DiffSpan(buffer.toString(), unique: current));
  return List.unmodifiable(spans);
}
