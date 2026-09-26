import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/sac_resolver.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Index of the sample nearest [branchSeconds] (earlier on ties), clamped.
int branchIndexFor(List<int> timestamps, int branchSeconds) {
  if (timestamps.isEmpty) return 0;
  var best = 0;
  for (var i = 1; i < timestamps.length; i++) {
    if ((timestamps[i] - branchSeconds).abs() <
        (timestamps[best] - branchSeconds).abs()) {
      best = i;
    }
  }
  return best;
}

/// The dive's complete state at [branchIndex], read from [actual] (tissues,
/// anchor, CNS, OTU) and [request] (tanks, pressures, SAC).
BranchState buildBranchState({
  required ScenarioRequest request,
  required ProfileAnalysis actual,
  required TankSchedule schedule,
  required int branchIndex,
}) {
  if (actual.decoStatuses.isEmpty) {
    throw StateError('actual analysis carries no deco statuses');
  }
  final i = branchIndex.clamp(0, actual.decoStatuses.length - 1);
  final status = actual.decoStatuses[i];
  final t = request.timestamps[i];
  final diveEnd = request.timestamps.last;
  final activeTankId = schedule.tankIdAt(t);
  final activeTank = schedule.tankById(activeTankId);
  final pressures = [
    for (final tank in request.tanks)
      tankPressureAt(
        tank: tank,
        series: request.tankPressures[tank.id],
        schedule: schedule,
        timestamp: t,
        diveEnd: diveEnd,
      ),
  ];
  final sac = resolveBranchSac(
    branchTimestamp: t,
    activeTank: activeTank,
    activeSeries: activeTankId == null
        ? null
        : request.tankPressures[activeTankId],
    schedule: schedule,
    timestamps: request.timestamps,
    depths: request.depths,
    environment: request.settings.environment,
    fallbackLpm: request.fallbackSacLpm,
    defaultLpm: request.settings.defaultSacLpm,
  );
  return BranchState(
    index: i,
    runtimeSeconds: t,
    depthMeters: request.depths[i],
    compartments: status.compartments,
    gfLowCeilingAnchor: status.gfLowCeilingAnchor ?? 0.0,
    cnsPercent: actual.cnsCurve != null && i < actual.cnsCurve!.length
        ? actual.cnsCurve![i]
        : 0.0,
    otu: actual.otuCurve != null && i < actual.otuCurve!.length
        ? actual.otuCurve![i]
        : 0.0,
    activeTankId: activeTankId,
    tankPressures: pressures,
    sacLitersPerMin: sac.litersPerMin,
    sacSource: sac.source,
  );
}
