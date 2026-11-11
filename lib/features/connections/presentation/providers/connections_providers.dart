import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';

import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(),
);

/// A filter naming `deco` or `gear.serviceDue` reads a local cache of engine
/// verdicts (#2365, #4461). Waits for those caches before the query, and
/// re-runs it when they are written, which the connections tick does not
/// follow.
Future<void> _awaitFilterCaches(Ref ref, DiveFilterState filter) async {
  final touched = diveFilterTablesTouched(filter);
  await awaitQueryCachesIfRead(ref, touched);
  final caches = touched.intersection(queryCacheTables);
  if (caches.isEmpty) return;
  ref.invalidateSelfWhen(
    ref.read(queryIdSetRunnerProvider).watchTables(caches),
  );
}

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
      await _awaitFilterCaches(ref, filter);
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
        sharedWith: view.mapSharedWith,
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

/// First and last calendar day of the log in scope; drives the timeline.
final connectionsDateSpanProvider = FutureProvider.autoDispose<DayRange?>((
  ref,
) async {
  final repository = ref.watch(connectionsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchConnectionsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  return repository.diveDateSpan(diverId: diverId);
});

/// The dive ids behind the selection, under the page's filter.
final connectionsSelectionDiveIdsProvider = FutureProvider.autoDispose
    .family<List<String>, GraphSelection>((ref, selection) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(connectionsFilterProvider);
      await _awaitFilterCaches(ref, filter);
      return repository.diveIdsFor(selection, diverId: diverId, filter: filter);
    });
