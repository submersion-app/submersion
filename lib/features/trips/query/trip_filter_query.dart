import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Lowers the trip filter to the query tree (#2365). The ONLY evaluator of
/// a TripFilterState: a field added to it and not named here fails
/// `trip_filter_query_census_test`.
extension TripFilterQuery on TripFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[
      // Trips whose dives used the item: the dive gear union, which also
      // counts a transmitter-matched cylinder.
      if (equipmentId != null)
        ScopedNode(
          FieldPath(['dives']),
          ConditionNode(
            FieldPath(['gear']),
            QueryOp.eq,
            RefValue(equipmentId!, equipmentId!),
          ),
        ),
      ?query,
    ];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

/// The one compile call the trip list shares.
CompiledQuery compileTripFilter(TripFilterState filter) =>
    compileQuery(filter.toQuery(), tripQueryEntity, appQueryRegistry);
