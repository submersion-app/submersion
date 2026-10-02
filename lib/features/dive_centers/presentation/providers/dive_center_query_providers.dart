import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The dive center list's query (#2365); null lists every center. The map
/// stays unfiltered, like the site map.
final diveCenterQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The center list narrowed to the query's ids; the list, compact pane and
/// table read this.
final filteredDiveCentersProvider = Provider<AsyncValue<List<DiveCenter>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(diveCenterListNotifierProvider),
    diveCenterQueryEntity,
    ref.watch(diveCenterQueryProvider),
    (c) => c.id,
  ),
);
