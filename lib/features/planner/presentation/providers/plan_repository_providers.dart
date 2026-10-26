import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// Repository singleton for saved dive plans.
final divePlanRepositoryProvider = Provider<DivePlanRepository>(
  (ref) => DivePlanRepository(),
);

/// Saved-plans list (newest first), live across saves/deletes/sync.
final divePlanSummariesProvider = FutureProvider<List<domain.DivePlanSummary>>((
  ref,
) async {
  final repository = ref.watch(divePlanRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchPlanChanges());
  return repository.getAllPlanSummaries();
});

/// Sort state for the full planned-dives list. Session-only, like the sort
/// and grouping on the Dive Sites list.
final divePlanSortProvider = StateProvider<SortState<DivePlanSortField>>(
  (ref) => const SortState(
    field: DivePlanSortField.date,
    direction: SortDirection.descending,
  ),
);
