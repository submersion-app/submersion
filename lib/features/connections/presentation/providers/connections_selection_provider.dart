import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// The node the graph is centred on (ego mode), or null for the whole web.
final connectionsFocusProvider = StateProvider<NodeRef?>((ref) => null);

/// The tapped node or edge, or null.
final connectionsSelectionProvider = StateProvider<GraphSelection?>(
  (ref) => null,
);
