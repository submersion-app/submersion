import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';

/// Tank volume assumed when a tank records none (PlanEngine's convention).
const double kAssumedTankVolumeLiters = 11.0;

/// Per-sample consumption over a timeline: litres per sample = SAC x ambient
/// (mean depth of the interval) x minutes, charged to the tank in force at
/// the interval start; pressures via the configured gas model. Samples
/// `i` in `(fromIndex, toIndex]` are charged.
List<TankConsumption> simulateConsumption({
  required List<int> timestamps,
  required List<double> depths,
  required TankSchedule schedule,
  required Map<String, double?> startPressures,
  required double Function(int sampleIndex) sacLpmAt,
  required DiveEnvironment environment,
  required GasModel gasModel,
  required double reservePressureBar,
  int fromIndex = 0,
  int? toIndex,
  PressureSource source = PressureSource.estimated,
}) {
  final tanks = schedule.tanks;
  final liters = <String, double>{for (final t in tanks) t.id: 0.0};
  final reserveAt = <String, int?>{for (final t in tanks) t.id: null};
  final emptyAt = <String, int?>{for (final t in tanks) t.id: null};
  final last = toIndex ?? timestamps.length - 1;

  double? pressureOf(String tankId) {
    final start = startPressures[tankId];
    if (start == null) return null;
    final tank = schedule.tankById(tankId)!;
    return pressureAfterConsuming(
      tankSizeLiters: tank.volume ?? kAssumedTankVolumeLiters,
      startPressureBar: start,
      litersConsumed: liters[tankId] ?? 0.0,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: gasModel,
    );
  }

  for (
    var i = (fromIndex < 1 ? 1 : fromIndex + 1);
    i <= last && i < timestamps.length;
    i++
  ) {
    final dt = timestamps[i] - timestamps[i - 1];
    if (dt <= 0) continue;
    final tankId = schedule.tankIdAt(timestamps[i - 1]);
    if (tankId == null || !liters.containsKey(tankId)) continue;
    final ambient = environment.pressureAtDepth(
      (depths[i] + depths[i - 1]) / 2.0,
    );
    liters[tankId] = liters[tankId]! + sacLpmAt(i) * ambient * dt / 60.0;
    final p = pressureOf(tankId);
    if (p != null) {
      if (reserveAt[tankId] == null && p <= reservePressureBar) {
        reserveAt[tankId] = timestamps[i];
      }
      if (emptyAt[tankId] == null && p <= 0) {
        emptyAt[tankId] = timestamps[i];
      }
    }
  }

  return [
    for (final t in tanks)
      TankConsumption(
        tankId: t.id,
        startPressureBar: startPressures[t.id],
        endPressureBar: pressureOf(t.id),
        litersUsed: liters[t.id] ?? 0.0,
        reserveReachedAtSeconds: reserveAt[t.id],
        emptyAtSeconds: emptyAt[t.id],
        source: startPressures[t.id] == null ? PressureSource.unknown : source,
      ),
  ];
}
