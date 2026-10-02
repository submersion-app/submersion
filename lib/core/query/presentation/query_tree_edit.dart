import 'package:submersion/core/query/domain/query_node.dart';

/// Where a node sits in a tree: one child index per level. Group children
/// are indexed in order; a [NotNode]'s child and a [ScopedNode]'s inner tree
/// are index 0.
typedef NodePath = List<int>;

// Pure edits over the immutable tree (#2365). Every function returns a new
// tree and never touches its input; the builder holds the result and hands
// it to the filter, which hashes it.

QueryNode? nodeAt(QueryNode root, NodePath path) {
  var node = root;
  for (final i in path) {
    final children = _children(node);
    if (i < 0 || i >= children.length) return null;
    node = children[i];
  }
  return node;
}

QueryNode replaceAt(QueryNode root, NodePath path, QueryNode replacement) {
  if (path.isEmpty) return replacement;
  final children = _children(root);
  final i = path.first;
  if (i < 0 || i >= children.length) {
    throw ArgumentError('no child $i under ${root.runtimeType}');
  }
  final updated = [
    for (var k = 0; k < children.length; k++)
      k == i
          ? replaceAt(children[k], path.sublist(1), replacement)
          : children[k],
  ];
  return _withChildren(root, updated);
}

/// Removes the node at [path]. A group left with one child stays a group
/// (the builder keeps showing its card); a group, NOT or scope left empty
/// is removed in turn. Null when the whole tree is gone.
QueryNode? removeAt(QueryNode root, NodePath path) {
  if (path.isEmpty) return null;
  final children = _children(root);
  final i = path.first;
  if (i < 0 || i >= children.length) {
    throw ArgumentError('no child $i under ${root.runtimeType}');
  }
  final replaced = path.length == 1
      ? null
      : removeAt(children[i], path.sublist(1));
  final updated = [
    for (var k = 0; k < children.length; k++)
      if (k != i) children[k] else ?replaced,
  ];
  if (updated.isEmpty) return null;
  return _withChildren(root, updated);
}

QueryNode appendChild(QueryNode root, NodePath groupPath, QueryNode child) {
  final group = nodeAt(root, groupPath);
  return switch (group) {
    AndNode(:final children) => replaceAt(
      root,
      groupPath,
      AndNode([...children, child]),
    ),
    OrNode(:final children) => replaceAt(
      root,
      groupPath,
      OrNode([...children, child]),
    ),
    _ => throw ArgumentError('$groupPath is not a group'),
  };
}

QueryNode toggleNegation(QueryNode root, NodePath path) {
  final node = nodeAt(root, path);
  if (node == null) throw ArgumentError('no node at $path');
  return replaceAt(root, path, node is NotNode ? node.child : NotNode(node));
}

QueryNode setGroupOp(QueryNode root, NodePath groupPath, {required bool and}) {
  final group = nodeAt(root, groupPath);
  final children = switch (group) {
    AndNode(:final children) => children,
    OrNode(:final children) => children,
    _ => throw ArgumentError('$groupPath is not a group'),
  };
  return replaceAt(root, groupPath, and ? AndNode(children) : OrNode(children));
}

/// A builder-made tree with no empty groups and no NOT NOT. One-child
/// groups are kept on purpose: a diver who just added a group with its
/// first row must see the card, and the compiler and printer take a
/// one-child group as they take any other.
QueryNode? normalizeQuery(QueryNode? node) {
  switch (node) {
    case null:
      return null;
    case AndNode(:final children):
      final kept = [for (final c in children) ?normalizeQuery(c)];
      return kept.isEmpty ? null : AndNode(kept);
    case OrNode(:final children):
      final kept = [for (final c in children) ?normalizeQuery(c)];
      return kept.isEmpty ? null : OrNode(kept);
    case NotNode(:final child):
      final inner = normalizeQuery(child);
      if (inner == null) return null;
      return inner is NotNode ? inner.child : NotNode(inner);
    case ScopedNode(:final path, :final inner):
      final kept = normalizeQuery(inner);
      return kept == null ? null : ScopedNode(path, kept);
    case ConditionNode():
    case TextNode():
      return node;
  }
}

/// The chips: one per top-level AND child, or the node itself.
List<QueryNode> topLevelConjuncts(QueryNode? node) => switch (node) {
  null => const [],
  AndNode(:final children) => children,
  _ => [node],
};

/// The tree without the chip at [index]. A single survivor is unwrapped:
/// a chip bar has no group card to keep.
QueryNode? removeTopLevelConjunct(QueryNode? node, int index) {
  final parts = topLevelConjuncts(node);
  if (index < 0 || index >= parts.length) return node;
  final kept = [
    for (var i = 0; i < parts.length; i++)
      if (i != index) parts[i],
  ];
  if (kept.isEmpty) return null;
  return kept.length == 1 ? kept.single : AndNode(kept);
}

List<QueryNode> _children(QueryNode node) => switch (node) {
  AndNode(:final children) => children,
  OrNode(:final children) => children,
  NotNode(:final child) => [child],
  ScopedNode(:final inner) => [inner],
  ConditionNode() || TextNode() => const [],
};

QueryNode _withChildren(QueryNode node, List<QueryNode> children) =>
    switch (node) {
      AndNode() => AndNode(children),
      OrNode() => OrNode(children),
      NotNode() => NotNode(children.single),
      ScopedNode(:final path) => ScopedNode(path, children.single),
      ConditionNode() || TextNode() => node,
    };
