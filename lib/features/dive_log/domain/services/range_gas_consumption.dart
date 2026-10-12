import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';

/// Gas consumption over part of a dive: [sac] in bar/min at the surface, in
/// bar of the dive's reference cylinder, and [rmv] in L/min at the surface.
/// Either is null when the data cannot give it.
typedef RangeGasConsumption = ({double? sac, double? rmv});

/// SAC and RMV between [startTimestamp] and [endTimestamp] (seconds from the
/// dive's start), at [avgDepth] meters, for the profile range panel (#2928).
///
/// The same two lanes as `Dive.sac` and `Dive.rmvFor`, with each cylinder's
/// start and end pressure read from its transmitter series at the range
/// edges instead of the whole dive's. A cylinder without a series adds
/// nothing: its logged start and end pressures say how much it dropped over
/// the dive, not when. SAC follows `referencePressureDrop`, reading the
/// reference cylinder alone on a rebreather ([isRebreather]); RMV sums every
/// cylinder with a volume under [model].
RangeGasConsumption rangeGasConsumption({
  required List<DiveTank> tanks,
  required Map<String, List<TankPressurePoint>> tankPressures,
  required int startTimestamp,
  required int endTimestamp,
  required double avgDepth,
  required GasModel model,
  bool isRebreather = false,
}) {
  const none = (sac: null, rmv: null);
  final minutes = (endTimestamp - startTimestamp) / 60;
  if (minutes <= 0 || tanks.isEmpty) return none;

  final series = resolveTankPressureSeries(tanks, tankPressures);
  final pressures = <String, ({double start, double end})>{};
  for (final tank in tanks) {
    final points = series[tank.id];
    if (points == null || points.length < 2) continue;
    final start = pressureAtTime(points, startTimestamp);
    final end = pressureAtTime(points, endTimestamp);
    if (start == null || end == null || start - end <= 0) continue;
    pressures[tank.id] = (start: start, end: end);
  }
  if (pressures.isEmpty) return none;

  // Ambient pressure in bar, the 1 bar reference gasVolume returns volumes
  // against.
  final ambientBar = avgDepth / 10 + 1;

  final drop = referencePressureDrop(
    reference: sacReferenceTankOf(tanks)!,
    tanks: tanks,
    referenceOnly: isRebreather,
    dropOf: (tank) {
      final p = pressures[tank.id];
      return p == null ? null : p.start - p.end;
    },
  );
  final sac = drop == null ? null : drop / minutes / ambientBar;

  double gasLiters = 0;
  for (final tank in tanks) {
    final p = pressures[tank.id];
    final volume = consumptionVolume(tank, tanks);
    if (p == null || volume == null) continue;
    double volumeAt(double bar) => gasVolume(
      tankSizeLiters: volume,
      pressureBar: bar,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: model,
    );
    final liters = volumeAt(p.start) - volumeAt(p.end);
    if (liters > 0) gasLiters += liters;
  }
  final rmv = gasLiters > 0 ? gasLiters / minutes / ambientBar : null;

  return (sac: sac, rmv: rmv);
}
