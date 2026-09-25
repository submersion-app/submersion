import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import 'connections_filter_provider.dart';
import 'connections_lens_provider.dart';
import 'connections_selection_provider.dart';

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(),
);

/// The graph for the active lens, filter and focus, trimmed to the node
/// budget given as the family key (the page picks 80 or 160 by width).
///
/// Not keyed by [ConnectionQuery]: `DiveFilterState` has no value equality,
/// so the query is rebuilt here from the individual providers instead.
final connectionGraphProvider = FutureProvider.autoDispose
    .family<ConnectionGraph, int>((ref, nodeBudget) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final lens = ref.watch(connectionsLensProvider);
      final filter = ref.watch(connectionsFilterProvider);
      final focus = ref.watch(connectionsFocusProvider);
      final query = ConnectionQuery(
        kindA: lens.kindA,
        kindB: lens.kindB,
        filter: filter,
        focus: focus,
        nodeBudget: nodeBudget,
      );
      return repository.loadGraph(query, diverId: diverId);
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
