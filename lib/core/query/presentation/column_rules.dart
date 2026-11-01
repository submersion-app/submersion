import 'package:submersion/core/query/domain/query_node.dart';

/// Column filter rules over a bare query tree (#2984, #3422): what a table
/// header or cell menu adds, resets and reports, for any entity. The dive
/// list's own helpers wrap these over its `DiveFilterState`.

/// The top-level AND children of [query], as the filter chips show them.
List<QueryNode> topLevelRules(QueryNode? query) => switch (query) {
  null => const [],
  AndNode(:final children) => children,
  final node => [node],
};

QueryNode? joinRules(List<QueryNode> nodes) => switch (nodes.length) {
  0 => null,
  1 => nodes.single,
  _ => AndNode(nodes),
};

/// Whether [node] is a rule on [key], plain or negated. A scoped relation
/// rule (`buddies[name contains "Sam"]`) is on the relation it scopes.
bool ruleIsOnKey(QueryNode node, String key) => switch (node) {
  ConditionNode(:final path) => path.segments.first == key,
  ScopedNode(:final path) => path.segments.first == key,
  NotNode(:final child) => ruleIsOnKey(child, key),
  _ => false,
};

/// [query] with [rule] ANDed as a new top-level child, so it shows as its
/// own removable chip; the same tree when an equal child is there already.
QueryNode addColumnRule(QueryNode? query, QueryNode rule) {
  final top = topLevelRules(query);
  if (top.contains(rule)) return query!;
  return joinRules([...top, rule])!;
}

/// [query] without every top-level rule on [key]; null when none is left.
/// Rules inside groups stay.
QueryNode? resetColumnRules(QueryNode? query, String key) {
  final top = topLevelRules(query);
  final kept = top.where((n) => !ruleIsOnKey(n, key)).toList();
  return kept.length == top.length ? query : joinRules(kept);
}

/// Whether [key] has a top-level rule.
bool isColumnFiltered(QueryNode? query, String key) =>
    topLevelRules(query).any((n) => ruleIsOnKey(n, key));
