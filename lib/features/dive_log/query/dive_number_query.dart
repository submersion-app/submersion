import 'package:submersion/core/query/domain/query_node.dart';

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

/// The dive number a search field holding only a whole number asks for
/// (`500`, `#500`, or the same in Arabic-Indic or full-width digits), or
/// null for anything else (#3455). The parser reads both as one free-text
/// word, so the list still searches them as text; only the jump list
/// treats them as a dive number too.
int? bareDiveNumber(QueryNode? node) {
  if (node is! TextNode || node.words.length != 1) return null;
  final match = _bareNumber.firstMatch(node.words.single);
  if (match == null) return null;
  return int.tryParse(_asciiDigits(match.group(1)!));
}

/// The dives numbered [number].
QueryNode diveNumberQuery(int number) => ConditionNode(
  FieldPath(['diveNumber']),
  QueryOp.eq,
  NumberValue(number.toDouble(), null),
);
