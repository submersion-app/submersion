import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';

/// The tapped node or edge, or null.
final connectionsSelectionProvider = StateProvider<GraphSelection?>(
  (ref) => null,
);
