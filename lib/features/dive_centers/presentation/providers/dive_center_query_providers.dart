import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

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

/// The filtered centers in the diver's chosen order, for the list and anything
/// that finds a row in it. A sort by count stays loading until the counts first
/// settle, as it cannot place a row without them; no other sort reads them.
final sortedDiveCentersProvider = Provider<AsyncValue<List<DiveCenter>>>((ref) {
  final centers = ref.watch(filteredDiveCentersProvider);
  final sort = ref.watch(diveCenterSortProvider);
  if (sort.field != DiveCenterSortField.diveCount) {
    return centers.whenData(
      (rows) => applyDiveCenterSorting(rows, sort, const {}),
    );
  }
  final counts = ref.watch(diveCenterDiveCountsProvider);
  if (!counts.hasSettled) return const AsyncValue.loading();
  return centers.whenData(
    (rows) => applyDiveCenterSorting(rows, sort, counts.value ?? const {}),
  );
});

/// The dive center a list returned to reopens and scrolls back to: the one last
/// opened, while the list as filtered still shows it (#3301).
final rememberedDiveCenterIdProvider = Provider<AsyncValue<String?>>(
  (ref) => rememberedListedId(
    items: ref.watch(filteredDiveCentersProvider),
    rememberedId: ref.watch(highlightedDiveCenterIdProvider),
    idOf: (center) => center.id,
  ),
);
