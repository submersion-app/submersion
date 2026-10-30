import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/models/sort_state_codec.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

/// Sort state for the full planned-dives list.
///
/// Comes back as the diver left it (issue #3748): the active diver's saved
/// sort, or the starting order below when there is none (or this build
/// cannot read it). Change it through `ListArrangementWrites`.
final divePlanSortProvider = Provider<SortState<DivePlanSortField>>(
  (ref) =>
      decodeSortState(
        ref.watch(
          settingsProvider.select((s) => s.listArrangements.divePlanSort),
        ),
        DivePlanSortField.values,
      ) ??
      const SortState(
        field: DivePlanSortField.date,
        direction: SortDirection.descending,
      ),
);
