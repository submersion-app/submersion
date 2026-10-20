import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

/// A new, sorted list of [plans] per [sort]. Does not mutate [plans].
///
/// A plan with no computed depth (`maxDepth == null`, a plan never run
/// through the engine) sorts as if its depth were zero, the same fallback
/// [DiveSortField.depth] uses for a dive with no recorded max depth.
List<DivePlanSummary> sortPlanSummaries(
  List<DivePlanSummary> plans,
  SortState<DivePlanSortField> sort,
) {
  final sorted = List<DivePlanSummary>.from(plans);
  final collator = TextCollator();
  // Name is alphabetical, like every other text field in this codebase:
  // "descending" is understood as Z-to-A for a number but as A-to-Z for a
  // name, so the comparison is inverted before direction is applied.
  final invertForText = sort.field == DivePlanSortField.name;

  sorted.sort((a, b) {
    final comparison = switch (sort.field) {
      DivePlanSortField.date => a.updatedAt.compareTo(b.updatedAt),
      DivePlanSortField.depth => (a.maxDepth ?? 0).compareTo(b.maxDepth ?? 0),
      DivePlanSortField.name => collator.compare(a.name, b.name),
    };
    final effective = invertForText ? -comparison : comparison;
    return sort.direction == SortDirection.ascending ? effective : -effective;
  });
  return sorted;
}
