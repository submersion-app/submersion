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
