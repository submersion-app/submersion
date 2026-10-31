import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Suggests a best breathing mix for [depthMeters] honouring [plan]'s Gas
/// options (`bestMixEndMeters`, `o2Narcotic`, and the plan's ppO2 ceilings),
/// falling back to [config]'s app-wide defaults for anything the plan leaves
/// unset. The O2 fraction is sized in the plan's water, the one its ppO2 is
/// judged in (issue #3913), so a suggestion never raises its own warning.
///
/// [forDeco] and [forDiluent] select which ppO2 ceiling gates the mix: the
/// deco ceiling for a stop/switch gas, the diluent MOD ppO2 for a CCR
/// diluent, or (with neither) the working ceiling for a bottom gas.
BestMixResult suggestBestMixForPlan(
  domain.DivePlan plan,
  PlanEngineConfig config, {
  required double depthMeters,
  bool forDeco = false,
  bool forDiluent = false,
}) {
  assert(!(forDeco && forDiluent), 'a mix has one ppO2 ceiling');
  final resolved = config.resolvedFor(plan);
  final ppO2Limit = forDiluent
      ? resolved.ccrDiluentModPpO2
      : forDeco
      ? resolved.ppO2Deco
      : resolved.ppO2Working;
  return computeBestMix(
    BestMixInputs(
      depthMeters: depthMeters,
      ppO2Limit: ppO2Limit,
      endLimitMeters: resolved.bestMixEndMeters,
      o2Narcotic: resolved.o2Narcotic,
      ppO2Environment: PlanEngine.environmentFor(plan),
    ),
  );
}
