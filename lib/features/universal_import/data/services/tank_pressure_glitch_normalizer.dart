import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Replace every cylinder start or end pressure that the source took from a
/// signal dropout or a pre-valve lead-in reading of its own pressure series
/// with the first or last clean reading (issue #2441).
///
/// Applied once after parsing, like the surfacing rule, so it covers every
/// format at their common payload shape. `allTankPressures.tankIndex`
/// indexes the dive's `tanks` list by position, as `UddfEntityImporter`
/// resolves it.
///
/// Unlike the surfacing rule this is not a preference: a pressure read off a
/// transmitter that had lost its signal is wrong for every diver. Only a
/// value that matches a glitch reading is replaced, so a source that read
/// its pressures from a log header is left alone. The payload is rebuilt,
/// never mutated.
ImportPayload replaceGlitchedTankPressures(ImportPayload payload) {
  final dives = payload.entitiesOf(ImportEntityType.dives);
  if (dives.isEmpty) {
    return payload;
  }

  return ImportPayload(
    entities: {
      ...payload.entities,
      ImportEntityType.dives: [for (final dive in dives) _fixDive(dive)],
    },
    warnings: payload.warnings,
    metadata: payload.metadata,
    sourceDivers: payload.sourceDivers,
  );
}

Map<String, dynamic> _fixDive(Map<String, dynamic> dive) {
  final tanks = dive['tanks'];
  final profile = dive['profile'];
  if (tanks is! List || tanks.isEmpty || profile is! List || profile.isEmpty) {
    return dive;
  }

  final readingsByTank = _readingsByTank(profile);
  if (readingsByTank.isEmpty) {
    return dive;
  }

  var changed = false;
  final fixed = <Map<String, dynamic>>[];
  for (var i = 0; i < tanks.length; i++) {
    final tank = tanks[i];
    if (tank is! Map<String, dynamic>) {
      return dive;
    }
    final readings = readingsByTank[i];
    if (readings == null) {
      fixed.add(tank);
      continue;
    }
    final start = (tank['startPressure'] as num?)?.toDouble();
    final end = (tank['endPressure'] as num?)?.toDouble();
    final glitches = scanPressureGlitches(readings);
    final newStart = replaceGlitchedEndpoint(
      reportedBar: start,
      readings: readings,
      atStart: true,
      scan: glitches,
    );
    final newEnd = replaceGlitchedEndpoint(
      reportedBar: end,
      readings: readings,
      atStart: false,
      scan: glitches,
    );
    if (newStart == start && newEnd == end) {
      fixed.add(tank);
      continue;
    }
    changed = true;
    fixed.add({...tank, 'startPressure': newStart, 'endPressure': newEnd});
  }

  return changed ? {...dive, 'tanks': fixed} : dive;
}

/// Each cylinder's timed readings from the payload profile, in time order,
/// keyed by position in the dive's `tanks` list. Untimed points are skipped:
/// they cannot be placed in the series.
Map<int, List<PressureReading>> _readingsByTank(List<dynamic> profile) {
  final byTank = <int, List<PressureReading>>{};
  for (final raw in profile) {
    if (raw is! Map<String, dynamic>) continue;
    final t = (raw['timestamp'] as num?)?.toInt();
    if (t == null) continue;
    final all = raw['allTankPressures'];
    if (all is! List) continue;
    for (final entry in all) {
      if (entry is! Map<String, dynamic>) continue;
      final index = (entry['tankIndex'] as num?)?.toInt();
      final pressure = (entry['pressure'] as num?)?.toDouble();
      if (index != null && pressure != null && pressure.isFinite) {
        (byTank[index] ??= []).add((t: t, bar: pressure));
      }
    }
  }
  return {
    for (final entry in byTank.entries)
      entry.key: readingsInTimeOrder(entry.value),
  };
}
