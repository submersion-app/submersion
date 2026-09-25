import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_value.dart';

export 'package:submersion/core/query/domain/query_value.dart';

/// A dotted path from the root entity: relations, then optionally a field.
@immutable
class FieldPath {
  final List<String> segments;
  const FieldPath(this.segments);

  int get length => segments.length;

  @override
  bool operator ==(Object other) =>
      other is FieldPath && listEqualsShallow(other.segments, segments);
  @override
  int get hashCode => Object.hashAll(segments);
  @override
  String toString() => segments.join('.');
}

enum QueryOp {
  eq,
  neq,
  lt,
  lte,
  gt,
  gte,
  contains,
  inList,
  between,
  isEmpty,
  isSet;

  bool get takesValue => this != isEmpty && this != isSet;
}

/// The query tree (#2365). Pure data: the parser and the rule builder make
/// it, the printer shows it, the validator checks it, the compiler turns it
/// into SQL.
@immutable
sealed class QueryNode {
  const QueryNode();
}

class AndNode extends QueryNode {
  final List<QueryNode> children;
  const AndNode(this.children);
  @override
  bool operator ==(Object other) =>
      other is AndNode && listEqualsShallow(other.children, children);
  @override
  int get hashCode => Object.hash('and', Object.hashAll(children));
  @override
  String toString() => 'And($children)';
}

class OrNode extends QueryNode {
  final List<QueryNode> children;
  const OrNode(this.children);
  @override
  bool operator ==(Object other) =>
      other is OrNode && listEqualsShallow(other.children, children);
  @override
  int get hashCode => Object.hash('or', Object.hashAll(children));
  @override
  String toString() => 'Or($children)';
}

class NotNode extends QueryNode {
  final QueryNode child;
  const NotNode(this.child);
  @override
  bool operator ==(Object other) => other is NotNode && other.child == child;
  @override
  int get hashCode => Object.hash('not', child);
  @override
  String toString() => 'Not($child)';
}

/// `path op value`. [value] is null exactly when [op] takes none.
class ConditionNode extends QueryNode {
  final FieldPath path;
  final QueryOp op;
  final QueryValue? value;
  ConditionNode(this.path, this.op, this.value) {
    if (op.takesValue && value == null) {
      throw ArgumentError('$op needs a value');
    }
    if (!op.takesValue && value != null) {
      throw ArgumentError('$op takes no value');
    }
  }
  @override
  bool operator ==(Object other) =>
      other is ConditionNode &&
      other.path == path &&
      other.op == op &&
      other.value == value;
  @override
  int get hashCode => Object.hash(path, op, value);
  @override
  String toString() => 'Condition($path $op $value)';
}

/// `path[inner]`: [inner] is evaluated inside ONE row of the relation
/// [path] names, so `customFields[key = k AND value ~ v]` tests the same
/// row for both. A bare multi-hop condition is the same thing with a
/// single condition inside.
class ScopedNode extends QueryNode {
  final FieldPath path;
  final QueryNode inner;
  const ScopedNode(this.path, this.inner);
  @override
  bool operator ==(Object other) =>
      other is ScopedNode && other.path == path && other.inner == inner;
  @override
  int get hashCode => Object.hash(path, inner);
  @override
  String toString() => 'Scoped($path[$inner])';
}

/// Free text over the entity's declared search columns.
class TextNode extends QueryNode {
  final List<String> words;
  const TextNode(this.words);
  @override
  bool operator ==(Object other) =>
      other is TextNode && listEqualsShallow(other.words, words);
  @override
  int get hashCode => Object.hash('text', Object.hashAll(words));
  @override
  String toString() => 'Text($words)';
}
