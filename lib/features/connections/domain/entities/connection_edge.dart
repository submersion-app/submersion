import 'package:equatable/equatable.dart';

import 'node_ref.dart';

/// Two entities that shared [weight] dives.
///
/// Self-join lenses produce undirected edges with `source.id < target.id`;
/// mixed lenses keep the query's kind A as source and kind B as target.
class ConnectionEdge extends Equatable {
  const ConnectionEdge({
    required this.source,
    required this.target,
    required this.weight,
    required this.firstDiveAt,
    required this.lastDiveAt,
  });

  final NodeRef source;
  final NodeRef target;
  final int weight;
  final DateTime firstDiveAt;
  final DateTime lastDiveAt;

  bool touches(NodeRef ref) => source == ref || target == ref;

  /// The end that is not [ref], or null when [ref] is not on this edge.
  NodeRef? otherEnd(NodeRef ref) {
    if (source == ref) return target;
    if (target == ref) return source;
    return null;
  }

  ConnectionEdge copyWith({
    NodeRef? source,
    NodeRef? target,
    int? weight,
    DateTime? firstDiveAt,
    DateTime? lastDiveAt,
  }) {
    return ConnectionEdge(
      source: source ?? this.source,
      target: target ?? this.target,
      weight: weight ?? this.weight,
      firstDiveAt: firstDiveAt ?? this.firstDiveAt,
      lastDiveAt: lastDiveAt ?? this.lastDiveAt,
    );
  }

  @override
  List<Object?> get props => [source, target, weight, firstDiveAt, lastDiveAt];
}
