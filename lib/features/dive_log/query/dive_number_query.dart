import 'package:submersion/core/query/domain/query_node.dart';

final _bareNumber = RegExp(r'^#?(\d+)$');

/// The dive number a search field holding only a whole number asks for
/// (`500`, `#500`), or null for anything else (#3455). The parser reads
/// both as one free-text word, so the list still searches them as text;
/// only the jump list treats them as a dive number too.
int? bareDiveNumber(QueryNode? node) {
  if (node is! TextNode || node.words.length != 1) return null;
  final match = _bareNumber.firstMatch(node.words.single);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// The dives numbered [number].
QueryNode diveNumberQuery(int number) => ConditionNode(
  FieldPath(['diveNumber']),
  QueryOp.eq,
  NumberValue(number.toDouble(), null),
);
