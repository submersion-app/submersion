import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/surface_breathing.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';

/// A gas switch as [diveSurfaceBreathing] reads it.
typedef SwitchTime = ({String tankId, int timestamp});

/// The surface breathing a dive's recording shows (issue #2930), from the
/// same inputs wherever it is worked out: SAC by cylinder reads them from the
/// dive page's providers and the derived metrics sweep from the database, so
/// both stretch the gas-use window alike.
///
/// Only breathing cylinders count: a suit inflation bottle loses gas on the
/// surface without being breathed (issue #4243). [tankPressures] may be keyed
/// by a stale tank id; it is resolved as the dive page resolves it.
SurfaceBreathing? diveSurfaceBreathing({
  required List<DiveProfilePoint> profile,
  required List<DiveTank> tanks,
  required Iterable<SwitchTime> switches,
  required Map<String, List<TankPressurePoint>>? tankPressures,
}) {
  final underwater = gasUseWindowOf(
    profile,
    time: (p) => p.timestamp,
    depth: (p) => p.depth,
  );
  if (underwater == null) return null;

  final breathingIds = {for (final t in breathingTanks(tanks)) t.id};
  final resolved = resolveTankPressureSeries(tanks, tankPressures);
  var recordingStart = profile.first.timestamp;
  var recordingEnd = profile.first.timestamp;
  for (final p in profile) {
    if (p.timestamp < recordingStart) recordingStart = p.timestamp;
    if (p.timestamp > recordingEnd) recordingEnd = p.timestamp;
  }

  return surfaceBreathingOf(
    underwater: underwater,
    recordingStart: recordingStart,
    recordingEnd: recordingEnd,
    switchTimes: [
      for (final s in switches)
        if (breathingIds.contains(s.tankId)) s.timestamp,
    ],
    pressures: [
      for (final MapEntry(key: id, value: series) in resolved.entries)
        if (breathingIds.contains(id))
          [for (final p in series) (timestamp: p.timestamp, bar: p.pressure)],
    ],
  );
}

/// The gas-use window of [profile] stretched over the surface breathing
/// [diveSurfaceBreathing] finds, with that breathing. The window is null when
/// there is nothing to leave out, as [gasUseWindowOf] says.
({GasUseWindow? window, SurfaceBreathing? breathing}) diveGasUseWindow({
  required List<DiveProfilePoint> profile,
  required List<DiveTank> tanks,
  required Iterable<SwitchTime> switches,
  required Map<String, List<TankPressurePoint>>? tankPressures,
}) {
  final breathing = diveSurfaceBreathing(
    profile: profile,
    tanks: tanks,
    switches: switches,
    tankPressures: tankPressures,
  );
  return (
    window: gasUseWindowOf(
      profile,
      time: (p) => p.timestamp,
      depth: (p) => p.depth,
      surfaceBreathing: breathing,
    ),
    breathing: breathing,
  );
}
