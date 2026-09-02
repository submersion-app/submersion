import 'package:submersion/core/profile/surfacing_pressure.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Rewrite every dive's cylinder end pressures to the reading taken at the
/// moment the diver surfaced, wherever the payload shows the source simply
/// took the last sample it had (issue #1092).
///
/// Applied once after parsing, so it covers every format at their common
/// payload shape rather than each parser separately. Two details matter here:
///
/// * `allTankPressures.tankIndex` indexes the dive's `tanks` list by position,
///   which is how `UddfEntityImporter` resolves it. It is not the tank's
///   `order`.
/// * FIT derives a Garmin cylinder's volume from its own start, end and
///   volume-used figures. Normalizing after the parser has run keeps that
///   derivation on the numbers Garmin reported.
///
/// The payload is rebuilt rather than edited: nothing the caller passed in is
/// mutated. A dive with no profile, no tanks, or no end pressure that matches
/// the post-surfacing tail comes through untouched.
ImportPayload trimTankPressuresAtSurfacing(ImportPayload payload) {
  final dives = payload.entitiesOf(ImportEntityType.dives);
  if (dives.isEmpty) {
    return payload;
  }

  return ImportPayload(
    entities: {
      ...payload.entities,
      ImportEntityType.dives: [for (final dive in dives) _trimDive(dive)],
    },
    warnings: payload.warnings,
    metadata: payload.metadata,
  );
}

Map<String, dynamic> _trimDive(Map<String, dynamic> dive) {
  final tanks = dive['tanks'];
  final profile = dive['profile'];
  if (tanks is! List || tanks.isEmpty || profile is! List || profile.isEmpty) {
    return dive;
  }

  final readings = surfacingTankReadings(_points(profile));
  if (readings.isEmpty) {
    return dive;
  }

  var changed = false;
  final trimmed = <Map<String, dynamic>>[];
  for (var i = 0; i < tanks.length; i++) {
    final tank = tanks[i];
    if (tank is! Map<String, dynamic>) {
      return dive;
    }
    final reported = (tank['endPressure'] as num?)?.toDouble();
    final end = trimEndPressureBar(reportedBar: reported, reading: readings[i]);
    if (end == reported) {
      trimmed.add(tank);
      continue;
    }
    changed = true;
    trimmed.add({...tank, 'endPressure': end});
  }

  return changed ? {...dive, 'tanks': trimmed} : dive;
}

/// Reduce payload profile points to what the surfacing rule reads. A point
/// missing either a depth or a timestamp cannot place the surfacing moment, so
/// it is skipped.
///
/// Skipping the untimed ones matters as much as skipping the depthless ones.
/// The rule takes surfacing to be the latest deep sample, so reading a missing
/// timestamp as zero would rank every untimed sample ahead of the whole dive:
/// a profile that stamped only its tail would place surfacing at the start and
/// promote a mid-dive pressure into the end pressure. Dropping them instead
/// leaves such a dive uncorrected, which is what this rule does whenever it
/// cannot tell where the dive ended.
List<SurfacingProfilePoint> _points(List<dynamic> profile) {
  final points = <SurfacingProfilePoint>[];
  for (final raw in profile) {
    if (raw is! Map<String, dynamic>) continue;
    final depth = (raw['depth'] as num?)?.toDouble();
    if (depth == null) continue;
    final timeSeconds = (raw['timestamp'] as num?)?.toInt();
    if (timeSeconds == null) continue;

    final pressures = <int, double>{};
    final all = raw['allTankPressures'];
    if (all is List) {
      for (final entry in all) {
        if (entry is! Map<String, dynamic>) continue;
        final index = (entry['tankIndex'] as num?)?.toInt();
        final pressure = (entry['pressure'] as num?)?.toDouble();
        if (index != null && pressure != null) {
          pressures[index] = pressure;
        }
      }
    }

    points.add(
      SurfacingProfilePoint(
        timeSeconds: timeSeconds,
        depthMeters: depth,
        tankPressuresBar: pressures,
      ),
    );
  }
  return points;
}
