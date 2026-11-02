/// Reading a sentence typed in plain words (#3457): the date phrases and
/// filler words the parser understands on an entity that opts in. Pure Dart
/// over the token list.
library;

import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';

/// `between march 2018 and june 2019` is the longest form the grammar reads.
const int _longestDatePhrase = 6;

/// `closed circuit rebreather` and its translations fit in four words.
const int _longestLabelPhrase = 4;

final RegExp _bareYear = RegExp(r'^\d{4}$');

bool _isTerm(Token t) => t.kind == TokenKind.word || t.kind == TokenKind.number;

/// The date phrase starting at token [start] and how many tokens it spans, or
/// null when none does. A lone year is not a phrase, because `2018` also finds
/// the notes and the dive numbered 2018; after `in` or `during` it is.
({DateRange range, int length})? readDatePhrase(
  List<Token> tokens,
  int start,
  DateTime now,
) {
  if (tokens[start].kind == TokenKind.word) {
    final lead = tokens[start].text.toLowerCase();
    if (lead == 'in' || lead == 'during') {
      final inner = _longestPhrase(tokens, start + 1, now, yearAlone: true);
      if (inner == null) return null;
      return (range: inner.range, length: inner.length + 1);
    }
  }
  return _longestPhrase(tokens, start, now, yearAlone: false);
}

({DateRange range, int length})? _longestPhrase(
  List<Token> tokens,
  int start,
  DateTime now, {
  required bool yearAlone,
}) {
  var run = 0;
  while (run < _longestDatePhrase &&
      start + run < tokens.length &&
      _isTerm(tokens[start + run])) {
    run++;
  }
  for (var length = run; length > 0; length--) {
    final text = tokens
        .sublist(start, start + length)
        .map((t) => t.text)
        .join(' ');
    if (length == 1 && !yearAlone && _bareYear.hasMatch(text)) continue;
    final range = parseDateText(text, now: now);
    if (range != null) return (range: range, length: length);
  }
  return null;
}

/// How many word tokens from [start] spell one term by [isPhrase], longest
/// first, or null when they spell none.
int? readLabelPhrase(
  List<Token> tokens,
  int start,
  bool Function(List<String> words) isPhrase,
) {
  var run = 0;
  while (run < _longestLabelPhrase &&
      start + run < tokens.length &&
      tokens[start + run].kind == TokenKind.word) {
    run++;
  }
  for (var length = run; length > 1; length--) {
    final words = [
      for (final t in tokens.sublist(start, start + length))
        t.text.toLowerCase(),
    ];
    if (isPhrase(words)) return length;
  }
  return null;
}

/// Whether a bare [word] only joins a sentence together. English always
/// counts, since the date grammar reads it; the [language] adds its own.
/// Hungarian, Arabic, Hebrew and Chinese attach these to the word they qualify
/// or write no space, so they list none.
bool isFillerWord(String word, String? language) {
  final lower = word.toLowerCase();
  return _englishFillers.contains(lower) ||
      (_fillers[language]?.contains(lower) ?? false);
}

const Set<String> _englishFillers = {
  'with',
  'in',
  'at',
  'on',
  'from',
  'the',
  'of',
  'near',
  'during',
};

const Map<String, Set<String>> _fillers = {
  'de': {'mit', 'im', 'am', 'an', 'auf', 'von', 'der', 'die', 'das'},
  'es': {'con', 'en', 'de', 'del', 'el', 'la'},
  'fr': {'avec', 'en', 'au', 'de', 'du', 'le', 'la'},
  'it': {'con', 'al', 'di', 'del', 'il', 'la'},
  'nl': {'met', 'op', 'bij', 'van', 'de', 'het'},
  'pt': {'com', 'em', 'no', 'na', 'de', 'do', 'da'},
};
