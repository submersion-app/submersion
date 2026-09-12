import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Suggests a best breathing mix for [depthMeters] honouring [plan]'s Gas
/// options (`bestMixEndMeters`, `o2Narcotic`, and the plan's ppO2 ceilings),
/// falling back to [config]'s app-wide defaults for anything the plan leaves
/// unset.
///
/// [forDeco] selects which ppO2 ceiling gates the mix: the deco ceiling for a
/// stop/switch gas, or the working ceiling for a bottom gas.
BestMixResult suggestBestMixForPlan(
  domain.DivePlan plan,
  PlanEngineConfig config, {
  required double depthMeters,
  bool forDeco = false,
}) {
  final resolved = config.resolvedFor(plan);
  return computeBestMix(
    BestMixInputs(
      depthMeters: depthMeters,
      ppO2Limit: forDeco ? resolved.ppO2Deco : resolved.ppO2Working,
      endLimitMeters: resolved.endLimitMeters,
      o2Narcotic: resolved.o2Narcotic,
    ),
  );
}
