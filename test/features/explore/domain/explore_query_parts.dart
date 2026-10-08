import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';

/// The top-level conditions of a query, flattening one AND.
List<QueryNode> partsIn(QueryNode? query) => switch (query) {
  null => const [],
  AndNode(:final children) => children,
  final node => [node],
};

/// The top-level conditions of a compiled query.
List<QueryNode> partsOf(ExploreCompilation c) => partsIn(c.query);

/// The top-level conditions of [query] on [path] with [op], in order.
List<ConditionNode> conditionsIn(
  QueryNode? query,
  List<String> path,
  QueryOp op,
) => [
  for (final n in partsIn(query).whereType<ConditionNode>())
    if (n.path == FieldPath(path) && n.op == op) n,
];

List<ConditionNode> conditionsOf(
  ExploreCompilation c,
  List<String> path,
  QueryOp op,
) => conditionsIn(c.query, path, op);

/// The number bound on the dive field [key] with [op], or null.
double? boundIn(QueryNode? query, String key, QueryOp op) {
  final found = conditionsIn(query, [key], op);
  if (found.isEmpty) return null;
  return (found.single.value! as NumberValue).value;
}

double? boundOf(ExploreCompilation c, String key, QueryOp op) =>
    boundIn(c.query, key, op);

/// The date bound with [op], or null.
DateTime? dateBoundOf(ExploreCompilation c, QueryOp op) {
  final found = conditionsOf(c, ['date'], op);
  if (found.isEmpty) return null;
  return (found.single.value! as DateValue).day;
}

/// The ref ids of the membership condition on [path] (empty when absent).
List<String> refIdsIn(QueryNode? query, List<String> path) => [
  for (final n in conditionsIn(query, path, QueryOp.inList))
    for (final v in (n.value! as ListValue).items) (v as RefValue).id,
];

List<String> refIdsOf(ExploreCompilation c, List<String> path) =>
    refIdsIn(c.query, path);
