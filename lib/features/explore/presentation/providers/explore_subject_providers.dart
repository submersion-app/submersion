import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_repository_provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// One row of a non-dive answer (phase 3): the list's own row [item], so
/// the list's own tile draws it, with its name and its dives in the scope.
class ExploreSubjectRow {
  final String id;
  final String name;
  final int dives;

  /// A `SiteWithDiveCount`, `EquipmentItem`, `BuddyWithDiveCount`,
  /// `SeenSpecies`, `TripWithStats` or `DiveCenter`, by the subject.
  final Object item;
  const ExploreSubjectRow({
    required this.id,
    required this.name,
    required this.dives,
    required this.item,
  });
}

/// Dives in the scope per row of the published subject, refreshed on a
/// write to any table the count reads.
final exploreSubjectCountsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final subject = ref.watch(exploreSubjectProvider);
  if (subject == ParsedSubject.dives) return const {};
  final scope = ref.watch(exploreDiveScopeProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final dives = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(
    dives.watchTables({
      'dives',
      ...diveFilterTablesTouched(DiveFilterState(query: scope)),
      ...ExploreRepository.subjectCountTables(subject),
    }),
  );
  return ref
      .watch(exploreRepositoryProvider)
      .diveCountsBySubject(subject, scope, diverId: diverId);
});

/// The equipment list's filter for an Explore query. The list's unset
/// status hides retired and sold gear, so a status the sentence names
/// ("my retired regulators") becomes that axis, lifted out of the query,
/// rather than contradicting it. A negated status, or several, stays in the
/// query and reads every status (#2590), as does a query on the active flag:
/// under the default view "retired or sold gear" would find nothing.
EquipmentFilterState exploreEquipmentFilter(QueryNode? node) {
  EquipmentStatus? named(QueryNode n) {
    if (n is! ConditionNode || n.op != QueryOp.inList) return null;
    if (n.path != FieldPath(const ['status'])) return null;
    final v = n.value;
    if (v is! ListValue || v.items.length != 1) return null;
    final item = v.items.single;
    if (item is! EnumValue) return null;
    return EquipmentStatus.values.where((s) => s.name == item.name).firstOrNull;
  }

  final parts = switch (node) {
    null => const <QueryNode>[],
    AndNode(:final children) => children,
    _ => [node],
  };
  for (final part in parts) {
    final status = named(part);
    if (status == null) continue;
    final rest = [
      for (final p in parts)
        if (!identical(p, part)) p,
    ];
    return EquipmentFilterState(
      status: status,
      query: switch (rest) {
        [] => null,
        [final only] => only,
        _ => AndNode(rest),
      },
    );
  }
  return EquipmentFilterState(
    allStatuses: node != null && _namesStatus(node),
    query: node,
  );
}

/// Whether [node] tests the equipment's own status, or the legacy active
/// flag the default view also pins, anywhere. A scoped condition reads
/// another entity's fields, so it is not looked into.
bool _namesStatus(QueryNode node) => switch (node) {
  AndNode(:final children) ||
  OrNode(:final children) => children.any(_namesStatus),
  NotNode(:final child) => _namesStatus(child),
  ConditionNode(:final path) =>
    path == FieldPath(const ['status']) || path == FieldPath(const ['active']),
  ScopedNode() || TextNode() => false,
};

/// [items] as ranked rows: most dives in the scope first, then by name.
AsyncValue<List<ExploreSubjectRow>> _ranked<T extends Object>(
  AsyncValue<List<T>> items,
  AsyncValue<Map<String, int>> counts,
  String Function(T) idOf,
  String Function(T) nameOf,
) {
  if (items.hasError) {
    return AsyncValue.error(items.error!, items.stackTrace!);
  }
  if (counts.hasError) {
    return AsyncValue.error(counts.error!, counts.stackTrace!);
  }
  final list = items.value;
  final byId = counts.value;
  if (list == null || byId == null) return const AsyncValue.loading();
  final rows = [
    for (final t in list)
      ExploreSubjectRow(
        id: idOf(t),
        name: nameOf(t),
        dives: byId[idOf(t)] ?? 0,
        item: t,
      ),
  ];
  rows.sort((a, b) {
    final byDives = b.dives.compareTo(a.dives);
    return byDives != 0
        ? byDives
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return AsyncValue.data(rows);
}

/// The published subject's rows the query selects, ranked. Each subject is
/// narrowed the way its own list narrows it, so the rows are the ones a
/// handoff lands on: sites and trips keep shared and unowned rows,
/// equipment its owner scope and default status axis.
final exploreSubjectRowsProvider =
    Provider<AsyncValue<List<ExploreSubjectRow>>>((ref) {
      final subject = ref.watch(exploreSubjectProvider);
      final node = ref.watch(exploreQueryNodeProvider);
      final counts = ref.watch(exploreSubjectCountsProvider);
      switch (subject) {
        case ParsedSubject.dives:
          return const AsyncValue.data([]);
        case ParsedSubject.sites:
          return _ranked(
            narrowByIds(
              ref.watch(sitesWithCountsProvider),
              ref.watch(
                queryFilteredSiteIdsProvider(SiteFilterState(query: node)),
              ),
              (s) => s.site.id,
            ),
            counts,
            (s) => s.site.id,
            (s) => s.site.name,
          );
        case ParsedSubject.equipment:
          final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
          return _ranked(
            narrowByIds(
              ref.watch(allEquipmentProvider),
              ref.watch(
                queryFilteredEquipmentIdsProvider((
                  filter: exploreEquipmentFilter(node),
                  diverId: diverId,
                )),
              ),
              (e) => e.id,
            ),
            counts,
            (e) => e.id,
            (e) => e.name,
          );
        case ParsedSubject.trips:
          return _ranked(
            narrowByIds(
              ref.watch(allTripsWithStatsProvider),
              ref.watch(
                queryFilteredTripIdsProvider(TripFilterState(query: node)),
              ),
              (t) => t.trip.id,
            ),
            counts,
            (t) => t.trip.id,
            (t) => t.trip.name,
          );
        case ParsedSubject.buddies:
          return _ranked(
            narrowByQuery(
              ref,
              ref.watch(allBuddiesWithDiveCountProvider),
              buddyQueryEntity,
              node,
              (b) => b.buddy.id,
            ),
            counts,
            (b) => b.buddy.id,
            (b) => b.buddy.name,
          );
        case ParsedSubject.centers:
          return _ranked(
            narrowByQuery(
              ref,
              ref.watch(allDiveCentersProvider),
              diveCenterQueryEntity,
              node,
              (c) => c.id,
            ),
            counts,
            (c) => c.id,
            (c) => c.name,
          );
        case ParsedSubject.species:
          return _ranked(
            narrowByQuery(
              ref,
              ref.watch(seenSpeciesProvider),
              speciesQueryEntity,
              node,
              (s) => s.species.id,
            ),
            counts,
            (s) => s.species.id,
            (s) => s.species.commonName,
          );
      }
    });
