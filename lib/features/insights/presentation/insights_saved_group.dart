import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

/// What the Insights [filter] narrows to, in the form a saved query stores
/// it, or null when it narrows nothing.
QueryNode? insightsFilterQuery(DiveFilterState filter) {
  final node = normalizeQuery(filter.toQuery());
  return node == null ? null : flattenOneChildGroups(node);
}

/// The saved query [filter] is, or null when it is none of [loads] (#3479).
///
/// Derived rather than remembered, so there is no second "selected group"
/// to fall out of step with the filter: a group saved a moment ago shows at
/// once, and editing one in the Refine panel leaves it.
///
/// Compared without ref labels. A filter lowers a tag to (id, id) while
/// loading a saved query puts the tag's current name in its place, so the
/// same tag would otherwise read as a different query.
SavedQueryLoad? activeSavedGroup(
  DiveFilterState filter,
  List<SavedQueryLoad> loads,
) {
  final query = insightsFilterQuery(filter);
  if (query == null) return null;
  final wanted = _withoutRefLabels(query);
  for (final load in loads) {
    final node = load.node;
    if (node == null) continue;
    if (_withoutRefLabels(flattenOneChildGroups(node)) == wanted) return load;
  }
  return null;
}

QueryNode _withoutRefLabels(QueryNode node) => switch (node) {
  AndNode(:final children) => AndNode(children.map(_withoutRefLabels).toList()),
  OrNode(:final children) => OrNode(children.map(_withoutRefLabels).toList()),
  NotNode(:final child) => NotNode(_withoutRefLabels(child)),
  ScopedNode(:final path, :final inner) => ScopedNode(
    path,
    _withoutRefLabels(inner),
  ),
  ConditionNode(:final path, :final op, :final value) => ConditionNode(
    path,
    op,
    value == null ? null : _withoutRefLabel(value),
  ),
  TextNode() => node,
};

QueryValue _withoutRefLabel(QueryValue value) => switch (value) {
  RefValue(:final id) => RefValue(id, id),
  ListValue(:final items) => ListValue(items.map(_withoutRefLabel).toList()),
  _ => value,
};
