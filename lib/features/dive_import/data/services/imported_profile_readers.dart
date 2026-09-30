import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One parsed profile sample as a [DiveProfilePoint], moved [offsetSeconds]
/// along the dive's timeline (a further computer whose clock started later).
///
/// Includes setpoint and ppO2 sensor readings. UDDF carries no millivolt
/// field; those arrive only via the libdivecomputer path that shares this
/// map (issue #810).
DiveProfilePoint profilePointFromImport(
  Map<String, dynamic> p, {
  int offsetSeconds = 0,
}) => DiveProfilePoint(
  timestamp: (p['timestamp'] as int? ?? 0) + offsetSeconds,
  depth: asDoubleOrNull(p['depth']) ?? 0.0,
  temperature: asDoubleOrNull(p['temperature']),
  heartRate: p['heartRate'] as int?,
  cns: asDoubleOrNull(p['cns']),
  ndl: p['ndl'] as int?,
  tts: p['tts'] as int?,
  ceiling: asDoubleOrNull(p['ceiling']),
  rbt: p['rbt'] as int?,
  decoType: p['decoType'] as int?,
  setpoint: asDoubleOrNull(p['setpoint']),
  ppO2: asDoubleOrNull(p['ppO2']),
  o2Sensor1: asDoubleOrNull(p['o2Sensor1']),
  o2Sensor2: asDoubleOrNull(p['o2Sensor2']),
  o2Sensor3: asDoubleOrNull(p['o2Sensor3']),
  o2Sensor4: asDoubleOrNull(p['o2Sensor4']),
  o2Sensor5: asDoubleOrNull(p['o2Sensor5']),
  o2Sensor6: asDoubleOrNull(p['o2Sensor6']),
  o2SensorMv1: p['o2SensorMv1'] as int?,
  o2SensorMv2: p['o2SensorMv2'] as int?,
  o2SensorMv3: p['o2SensorMv3'] as int?,
  o2SensorMv4: p['o2SensorMv4'] as int?,
  o2SensorMv5: p['o2SensorMv5'] as int?,
  o2SensorMv6: p['o2SensorMv6'] as int?,
);

/// The per-tank pressure readings in parsed profile samples, keyed by the id
/// of the stored tank each `tankIndex` names and moved [offsetSeconds] along
/// the dive's timeline. Readings for a tank index the dive does not have are
/// dropped.
Map<String, List<({int timestamp, double pressure})>> tankPressuresFromImport(
  List<Map<String, dynamic>> profileData,
  List<DiveTank> tanks, {
  int offsetSeconds = 0,
}) {
  final pressuresByTank = <String, List<({int timestamp, double pressure})>>{};
  for (final p in profileData) {
    final timestamp = (p['timestamp'] as int? ?? 0) + offsetSeconds;
    final allTankPressures =
        p['allTankPressures'] as List<Map<String, dynamic>>?;
    if (allTankPressures == null) continue;
    for (final tp in allTankPressures) {
      final pressure = tp['pressure'] as double?;
      final tankIdx = tp['tankIndex'] as int? ?? 0;
      if (pressure != null && tankIdx >= 0 && tankIdx < tanks.length) {
        pressuresByTank.putIfAbsent(tanks[tankIdx].id, () => []).add((
          timestamp: timestamp,
          pressure: pressure,
        ));
      }
    }
  }
  return pressuresByTank;
}
