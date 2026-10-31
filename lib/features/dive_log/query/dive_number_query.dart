import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';

final _bareNumber = RegExp(
  r'^#?([0-9\u0660-\u0669\u06F0-\u06F9\uFF10-\uFF19]+)$',
);

/// The code point of zero in each digit set a keyboard here may type:
/// Arabic-Indic, Eastern Arabic-Indic (Persian, Urdu) and full-width (a
/// CJK input method). ASCII digits need no mapping.
const _digitZeros = [0x0660, 0x06F0, 0xFF10];

String _asciiDigits(String digits) => String.fromCharCodes(
  digits.runes.map((r) {
    for (final zero in _digitZeros) {
      if (r >= zero && r <= zero + 9) return 0x30 + r - zero;
    }
    return r;
  }),
);

/// The dive number [word] spells (`500`, `#500`, or the same in Arabic-Indic
/// or full-width digits), or null for anything else.
int? _diveNumberOfWord(String word) {
  final match = _bareNumber.firstMatch(word);
  if (match == null) return null;
  return int.tryParse(_asciiDigits(match.group(1)!));
}

/// The dive number a search field holding only a whole number asks for, or
/// null for anything else (#3455). The parser reads it as one free-text word:
/// [kDiveNumberTextSearch] finds the dive through that word, and the jump
/// list leads with it.
int? bareDiveNumber(QueryNode? node) {
  if (node is! TextNode || node.words.length != 1) return null;
  return _diveNumberOfWord(node.words.single);
}

/// A search word that is a whole number also finds the dives with exactly
/// that number, wherever dive text is searched (#3653). The number is exact,
/// unlike the text it joins: `500` finds dive 500, not dive 1500. The bind is
/// a string, and the bare INTEGER column's affinity compares it as a number,
/// so wrapping the column in an expression would match nothing.
const kDiveNumberTextSearch = TextSearchExpansion(
  sql: '{r}.dive_number IN ({values})',
  values: _diveNumberTerms,
);

Iterable<String> _diveNumberTerms(String term) {
  final number = _diveNumberOfWord(term.trim());
  return number == null ? const [] : ['$number'];
}

/// The dives numbered [number].
QueryNode diveNumberQuery(int number) => ConditionNode(
  FieldPath(['diveNumber']),
  QueryOp.eq,
  NumberValue(number.toDouble(), null),
);
