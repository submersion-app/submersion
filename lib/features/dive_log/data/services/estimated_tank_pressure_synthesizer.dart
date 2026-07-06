import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// Real per-tank pressures augmented with in-memory linear estimates, plus the
/// set of tankIds that were synthesized (so the UI can label them "estimated").
class EstimatedTankPressures {
  final Map<String, List<TankPressurePoint>> pressures;
  final Set<String> estimatedTankIds;
  const EstimatedTankPressures(this.pressures, this.estimatedTankIds);
}

/// Builds transmitter-style linear pressure series for tanks that have both
/// start/end pressures but no time-series data. Never persists; pure.
///
/// For each qualifying tank the series is flat at startPressure until the tank
/// is first breathed, drops linearly while breathed (windowed by gas switches),
/// holds flat during gaps, and ends flat at endPressure. The total drop is
/// distributed across active windows in proportion to their duration.
EstimatedTankPressures synthesizeEstimatedTankPressures({
  required Map<String, List<TankPressurePoint>> existing,
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
}) {
  final pressures = <String, List<TankPressurePoint>>{...existing};
  final estimated = <String>{};
  if (diveDurationSeconds <= 0) {
    return EstimatedTankPressures(pressures, estimated);
  }

  final intervals = buildActiveTankIntervals(
    tanks: tanks,
    gasSwitches: gasSwitches,
    diveDurationSeconds: diveDurationSeconds,
  );

  for (final tank in tanks) {
    if (existing[tank.id]?.isNotEmpty ?? false) continue;
    final start = tank.startPressure;
    final end = tank.endPressure;
    if (start == null || end == null || start <= end) continue;

    final windows = intervals[tank.id] ?? const <({int start, int end})>[];
    final points = _buildFlatDropFlat(
      tankId: tank.id,
      startPressure: start,
      endPressure: end,
      // Fallback: a tank with start/end but no gas-switch evidence gets a
      // single full-dive window (a plain straight line).
      windows: windows.isEmpty
          ? [(start: 0, end: diveDurationSeconds)]
          : windows,
      diveDurationSeconds: diveDurationSeconds,
    );
    pressures[tank.id] = points;
    estimated.add(tank.id);
  }
  return EstimatedTankPressures(pressures, estimated);
}

List<TankPressurePoint> _buildFlatDropFlat({
  required String tankId,
  required double startPressure,
  required double endPressure,
  required List<({int start, int end})> windows,
  required int diveDurationSeconds,
}) {
  final sorted = [...windows]..sort((a, b) => a.start.compareTo(b.start));
  final totalActive = sorted.fold<int>(0, (s, w) => s + (w.end - w.start));
  if (totalActive <= 0) {
    return [
      _pt(tankId, 0, startPressure),
      _pt(tankId, diveDurationSeconds, endPressure),
    ];
  }
  final dropRate = (startPressure - endPressure) / totalActive;

  final points = <TankPressurePoint>[_pt(tankId, 0, startPressure)];
  var pressure = startPressure;

  if (sorted.first.start > 0) {
    points.add(_pt(tankId, sorted.first.start, startPressure));
  }
  for (var i = 0; i < sorted.length; i++) {
    final w = sorted[i];
    pressure -= dropRate * (w.end - w.start);
    points.add(_pt(tankId, w.end, pressure));
    if (i + 1 < sorted.length && sorted[i + 1].start > w.end) {
      points.add(_pt(tankId, sorted[i + 1].start, pressure));
    }
  }
  if (sorted.last.end < diveDurationSeconds) {
    points.add(_pt(tankId, diveDurationSeconds, endPressure));
  } else {
    // Clamp the final vertex to endPressure to absorb floating-point drift.
    points[points.length - 1] = _pt(tankId, sorted.last.end, endPressure);
  }
  return points;
}

TankPressurePoint _pt(String tankId, int ts, double pressure) =>
    TankPressurePoint(
      id: 'est-$tankId-$ts',
      tankId: tankId,
      timestamp: ts,
      pressure: pressure,
    );
