import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(),
);

/// The graph for the current view and filter, trimmed to the node budget
/// given as the family key (the page picks 80 or 160 by width).
final connectionGraphProvider = FutureProvider.autoDispose
    .family<ConnectionGraph, int>((ref, nodeBudget) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final view = ref.watch(connectionsViewProvider);
      final filter = ref.watch(connectionsFilterProvider);
      if (view.isAroundWithoutFocus) return ConnectionGraph.empty;
      if (view.mode == ConnectionsMode.around) {
        return repository.loadAround(
          focus: view.focus!,
          kinds: view.aroundKinds,
          hops: view.hops,
          diverId: diverId,
          filter: filter,
          nodeBudget: nodeBudget,
        );
      }
      return repository.loadMap(
        view.mapSpec,
        diverId: diverId,
        filter: filter,
        nodeBudget: nodeBudget,
      );
    });

/// Entities of any kind whose name contains the text, for the Around
/// search field.
final connectionsSearchProvider = FutureProvider.autoDispose
    .family<List<ConnectionNode>, String>((ref, text) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      return repository.searchEntities(text, diverId: diverId);
    });

/// The entities named by [wires] (comma-separated `kind:id`), for search
/// hits matched on a translated name. A String key keeps the family stable.
final connectionsNodesByWireProvider = FutureProvider.autoDispose
    .family<List<ConnectionNode>, String>((ref, wires) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final refs = [for (final w in wires.split(',')) ?NodeRef.parse(w)];
      if (refs.isEmpty) return const [];
      return repository.nodesFor(refs, diverId: diverId);
    });

/// First and last dive year for the current diver, for the year slider.
final connectionsYearSpanProvider =
    FutureProvider.autoDispose<({int first, int last})?>((ref) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      return repository.diveYearSpan(diverId: diverId);
    });

/// The dive ids behind the selection, under the page's filter.
final connectionsSelectionDiveIdsProvider = FutureProvider.autoDispose
    .family<List<String>, GraphSelection>((ref, selection) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(connectionsFilterProvider);
      return repository.diveIdsFor(selection, diverId: diverId, filter: filter);
    });
