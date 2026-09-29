import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_validator.dart';

/// The mission's blocking issues known without running the engine: its own
/// validation, the plan's (mode and tanks), and a leg the current blocks.
/// Empty with no mission. The route card and the status chip both read it.
final missionBlockingIssuesProvider = Provider<List<MissionIssue>>((ref) {
  // The plan check reads only the mode and the tanks.
  final (mission, _, _) = ref.watch(
    divePlanNotifierProvider.select((s) => (s.mission, s.mode, s.tanks)),
  );
  if (mission == null) return const [];
  final plan = divePlanFromState(ref.read(divePlanNotifierProvider));
  final cut = const MissionEngine().traversableRoute(mission).cut;
  return [
    for (final issue in [
      ...validateMission(mission),
      ...validatePlanForMission(plan),
      ?cut,
    ])
      if (issue.severity == MissionIssueSeverity.blocking) issue,
  ];
});
