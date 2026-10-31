import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Lowers the trip filter to the query tree (#2365). The ONLY evaluator of
/// a TripFilterState: a field added to it and not named here fails
/// `trip_filter_query_census_test`.
extension TripFilterQuery on TripFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[
      // Trips whose dives used the item: the dive gear union, which also
      // counts a transmitter-matched cylinder. One dive carries both
      // conditions, because a plan has not used the item (issue #3932).
      if (equipmentId != null)
        ScopedNode(
          FieldPath(['dives']),
          AndNode([
            ConditionNode(
              FieldPath(['planned']),
              QueryOp.eq,
              const BoolValue(false),
            ),
            ConditionNode(
              FieldPath(['gear']),
              QueryOp.eq,
              RefValue(equipmentId!, equipmentId!),
            ),
          ]),
        ),
      ?query,
    ];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

/// The one compile call the trip list shares. [diverId] reads a shared
/// trip's dives as that diver's alone, as the trip's stats do.
CompiledQuery compileTripFilter(TripFilterState filter, {String? diverId}) =>
    compileQuery(
      filter.toQuery(),
      tripQueryEntity,
      appQueryRegistry,
      diverId: diverId,
    );

/// The trips [diverId] can see, owned or shared and not hidden (issues #2594,
/// #2151), as a caller-applied scope over [rootAlias]. It compares rows with
/// the active diver, which a saved query must not name. Null narrows nothing,
/// as the trip list with no active diver.
QueryScope? visibleTripsScope(String rootAlias, String? diverId) {
  if (diverId == null) return null;
  final visible = VisibilityFilter.sqlFragment(
    tableAlias: rootAlias,
    diverId: diverId,
    conjunction: '',
    kind: SharedItemKind.trip,
  );
  return (
    sql: visible.whereClause,
    params: [for (final v in visible.variables) v.value!],
  );
}
