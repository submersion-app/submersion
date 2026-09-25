import 'package:equatable/equatable.dart';

import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// What the diver tapped on the canvas.
sealed class GraphSelection extends Equatable {
  const GraphSelection();
}

class NodeSelection extends GraphSelection {
  const NodeSelection(this.ref);
  final NodeRef ref;
  @override
  List<Object?> get props => [ref];
}

class EdgeSelection extends GraphSelection {
  const EdgeSelection(this.a, this.b);
  final NodeRef a;
  final NodeRef b;
  @override
  List<Object?> get props => [a, b];
}
