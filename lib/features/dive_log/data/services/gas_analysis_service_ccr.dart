part of 'gas_analysis_service.dart';

/// A CCR dive's rows of [GasAnalysisService.calculateCylinderSac], kept beside
/// the service so the main file stays under the size limit; a part shares its
/// private helpers.
extension _CcrCylinderSac on GasAnalysisService {
  /// A CCR dive's cylinders: a loop rate for the gas lost on the loop (see
  /// [ccrDiveUse]), and ordinary SAC and RMV only for the gas lost after a
  /// bailout (issue #4082).
  List<CylinderSac> _ccrCylinderSac({
    required Dive dive,
    required List<DiveProfilePoint> profile,
    required List<GasSwitchWithTank>? gasSwitches,
    required Map<String, List<TankPressurePoint>> resolvedPressures,
    required int diveEnd,
  }) {
    final use = ccrDiveUse(
      tanks: dive.tanks,
      gasSwitches: gasSwitches,
      tankPressures: resolvedPressures,
      diveEnd: diveEnd,
      gasModel: gasModel,
    );
    final results = <CylinderSac>[];
    for (var i = 0; i < dive.tanks.length; i++) {
      final tank = dive.tanks[i];
      final cylinder = use.cylinders[i];
      final series = resolvedPressures[tank.id];
      final (start, end) = resolvedTankPressures(tank, series);
      final volume = consumptionVolume(tank, dive.tanks);
      final windows = cylinder.bailoutWindows;
      final avgDepthOnBailout = windows.isEmpty
          ? null
          : timeWeightedMeanAcross(
              profile,
              windows: windows,
              time: (p) => p.timestamp,
              value: (p) => p.depth,
            );
      results.add(
        CylinderSac(
          tankId: tank.id,
          tankName: tank.name,
          gasMix: tank.gasMix,
          role: tank.role,
          tankVolume: volume,
          sacRate: _bailoutSacRate(
            cylinder: cylinder,
            tank: tank,
            tankVolume: volume,
            avgDepth: avgDepthOnBailout ?? dive.avgDepth,
            environment: dive.environment,
          ),
          loopRate: cylinder.loopRate,
          startPressure: start,
          endPressure: end,
          gasModel: gasModel,
          usageDuration: Duration(
            seconds: cylinder.bailoutStartBar != null
                ? windows.breathedSeconds
                : use.loopSeconds,
          ),
          avgDepthDuringUse: avgDepthOnBailout,
          hasTimeSeriesData: series != null,
          order: tank.order,
        ),
      );
    }
    results.sort((a, b) => a.order.compareTo(b.order));
    return results;
  }

  /// SAC for the gas [cylinder] lost after a bailout, over the time it was
  /// breathed. Null when it lost none.
  double? _bailoutSacRate({
    required CcrCylinderUse cylinder,
    required DiveTank tank,
    required double? tankVolume,
    required double? avgDepth,
    required DiveEnvironment environment,
  }) {
    final start = cylinder.bailoutStartBar;
    final end = cylinder.bailoutEndBar;
    final durationMin = cylinder.bailoutWindows.breathedSeconds / 60.0;
    if (start == null || end == null || durationMin <= 0 || avgDepth == null) {
      return null;
    }
    final ambientPressureBar = environment.pressureAtDepth(avgDepth);
    if (tankVolume != null) {
      return GasAnalysisService._zCorrectedSacRate(
        tankVolume: tankVolume,
        startPressureBar: start,
        endPressureBar: end,
        o2Percent: tank.gasMix.o2,
        hePercent: tank.gasMix.he,
        durationMin: durationMin,
        ambientPressureBar: ambientPressureBar,
        model: gasModel,
      );
    }
    return (start - end) / durationMin / ambientPressureBar;
  }
}
