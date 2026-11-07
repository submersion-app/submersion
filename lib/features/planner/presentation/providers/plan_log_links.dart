import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';

/// The saved plan linked to the logged dive [diveId] (issue #3565), which the
/// log links back to. The plan row's link is the only link: there is no column
/// on the dive. Null when no plan is linked, or the plan has since been
/// deleted, which simply takes the link away.
final planForLoggedDiveProvider = FutureProvider.family<String?, String>((
  ref,
  diveId,
) async {
  final plans = ref.watch(divePlanRepositoryProvider);
  ref.invalidateSelfWhen(plans.watchPlanChanges());
  return (await plans.getPlanByLinkedDiveId(diveId))?.id;
});
