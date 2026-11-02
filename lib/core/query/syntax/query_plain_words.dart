/// Reading a sentence typed in plain words (#3457): the date phrases and
/// filler words the parser understands on an entity that opts in. Pure Dart
/// over the token list.
library;

import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/syntax/query_parse_context.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';
import 'package:submersion/core/text/ascii_digits.dart';

/// `between 14th of march 2018 and 2nd of june 2019` is the longest form the
/// grammar reads.
const int _longestDatePhrase = 10;

/// `closed circuit rebreather` and its translations fit in five words.
const int kLongestLabelPhrase = 5;

final RegExp _bareYear = RegExp(r'^\d{4}$');

bool _isTerm(Token t) => t.kind == TokenKind.word || t.kind == TokenKind.number;

bool _isYearText(String text) => _bareYear.hasMatch(asciiDigits(text));

bool _isComma(Token t) => t.kind == TokenKind.symbol && t.text == ',';

bool _isYear(Token t) => _isTerm(t) && _isYearText(t.text);

/// The ordinal mark on the first of a month (`1º de maio`). On any other number
/// it is a temperature.
const Set<String> _firstOfMonthMarks = {'º', '°'};

/// A mark written straight after [term], so it belongs to the term: a dot
/// (`14. Oktober`, `2018. október 14.`) or the ordinal of the first.
bool _closesTerm(Token mark, Token term) =>
    mark.kind == TokenKind.word &&
    mark.offset == term.offset + term.length &&
    (mark.text == '.' ||
        (term.text == '1' && _firstOfMonthMarks.contains(mark.text)));

/// The words that mean "of" inside a date (`14 de octubre de 2018`). Other
/// fillers stay out: `30 en octubre 2018` is 30 in October, not 30 October.
/// English has `of`, which the grammar reads.
const Map<String, Set<String>> _dateJoiners = {
  'es': {'de', 'del'},
  'it': {'di', 'del'},
  'pt': {'de'},
};

bool _joinsDate(Token t, String? language) =>
    t.kind == TokenKind.word &&
    (_dateJoiners[language]?.contains(t.text.toLowerCase()) ?? false);

/// The date phrase starting at token [start] and how many tokens it spans, or
/// null when none does. A lone year is not a phrase, because `2018` also finds
/// the notes and the dive numbered 2018; after `in` or `during` it is.
({DateRange range, int length})? readDatePhrase(
  List<Token> tokens,
  int start,
  ParseContext context,
) {
  if (tokens[start].kind == TokenKind.word) {
    final lead = tokens[start].text.toLowerCase();
    if (lead == 'in' || lead == 'during') {
      final inner = readDateValue(tokens, start + 1, context);
      if (inner == null) return null;
      return (range: inner.range, length: inner.length + 1);
    }
  }
  return _longestPhrase(tokens, start, context, yearAlone: false);
}

/// The longest date from token [start], where a date is expected, so a lone
/// year counts.
({DateRange range, int length})? readDateValue(
  List<Token> tokens,
  int start,
  ParseContext context,
) => _longestPhrase(tokens, start, context, yearAlone: true);

({DateRange range, int length})? _longestPhrase(
  List<Token> tokens,
  int start,
  ParseContext context, {
  required bool yearAlone,
}) {
  // A comma can sit before a date's year (`october 14, 2018`), and a joining
  // word inside a date, so each is stepped over and counted but never read. Any
  // other comma separates terms. The list ends in the end token, which is
  // neither a term, a comma nor a joining word, so the index stays in range.
  final words = <String>[];
  final spans = <int>[];
  var next = start;
  while (words.length < _longestDatePhrase && _isTerm(tokens[next])) {
    final term = tokens[next++];
    words.add(term.text);
    if (_closesTerm(tokens[next], term)) next++;
    spans.add(next - start);
    if ((_isComma(tokens[next]) && _isYear(tokens[next + 1])) ||
        _joinsDate(tokens[next], context.language)) {
      next++;
    }
  }
  for (var count = words.length; count > 0; count--) {
    final text = words.take(count).join(' ');
    if (count == 1 && !yearAlone && _isYearText(text)) continue;
    final range = parseDateText(
      text,
      now: context.now,
      language: context.language,
    );
    if (range != null) return (range: range, length: spans[count - 1]);
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
  while (run < kLongestLabelPhrase &&
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
  'dive',
  'dives',
  'to',
  'my',
  'for',
  'a',
  'an',
};

const Map<String, Set<String>> _fillers = {
  'de': {'mit', 'im', 'am', 'an', 'auf', 'von', 'der', 'die', 'das'},
  'es': {'con', 'en', 'de', 'del', 'el', 'la'},
  'fr': {'avec', 'en', 'au', 'de', 'du', 'le', 'la'},
  'it': {'con', 'al', 'di', 'del', 'il', 'la'},
  'nl': {'met', 'op', 'bij', 'van', 'de', 'het'},
  'pt': {'com', 'em', 'no', 'na', 'de', 'do', 'da'},
};
