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
  bool blocking(MissionIssue i) => i.severity == MissionIssueSeverity.blocking;
  final own = validateMission(mission).where(blocking).toList();
  // Speeds exist only once the mission validates: a scooter with no speed
  // is not a current that blocks leg 1. The engine cuts the route the same
  // way, after validation.
  final cut = own.isEmpty
      ? const MissionEngine().traversableRoute(mission).cut
      : null;
  return [...own, ...validatePlanForMission(plan).where(blocking), ?cut];
});
