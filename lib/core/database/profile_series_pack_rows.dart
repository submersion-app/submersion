/// Row-decoding helpers for [profileSampleOf], split out of
/// `profile_series_pack.dart` to keep that file under the project's line
/// limit. Same imports discipline as the rest of `lib/core/database`: no
/// Flutter, only what a headless isolate can run.
library;

import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// Reads a legacy `dive_profiles` row by column name. Absent columns (an
/// older fixture or a partially migrated table) read as null. Returns null
/// when the row has no READABLE timestamp or depth: a restored or
/// hand-repaired legacy table can hold such rows and they cannot become a
/// sample.
///
/// `is! num` rather than a null check, because the two are the same thing
/// here. SQLite carries a storage class per value, so a REAL-affinity
/// column can hold text it could not convert, and a cast would throw. The
/// packer catches that per DIVE, so one unreadable byte would cost the
/// dive its whole profile and keep its legacy rows back for a retry that
/// re-reads the same byte and fails identically, forever.
ProfileSample? profileSampleOf(Map<String, Object?> data) {
  final timestamp = data['timestamp'];
  final depth = data['depth'];
  if (timestamp is! num || depth is! num) return null;
  return ProfileSample(
    timestamp: timestamp.toInt(),
    depth: depth.toDouble(),
    pressure: realOf(data['pressure']),
    temperature: realOf(data['temperature']),
    heartRate: intOf(data['heart_rate']),
    ascentRate: realOf(data['ascent_rate']),
    ceiling: realOf(data['ceiling']),
    ndl: intOf(data['ndl']),
    setpoint: realOf(data['setpoint']),
    ppO2: realOf(data['pp_o2']),
    o2Sensor1: realOf(data['o2_sensor1']),
    o2Sensor2: realOf(data['o2_sensor2']),
    o2Sensor3: realOf(data['o2_sensor3']),
    o2Sensor4: realOf(data['o2_sensor4']),
    o2Sensor5: realOf(data['o2_sensor5']),
    o2Sensor6: realOf(data['o2_sensor6']),
    cns: realOf(data['cns']),
    tts: intOf(data['tts']),
    rbt: intOf(data['rbt']),
    decoType: intOf(data['deco_type']),
    heartRateSource: data['heart_rate_source'] as String?,
    heading: realOf(data['heading']),
    o2SensorMv1: intOf(data['o2_sensor_mv1']),
    o2SensorMv2: intOf(data['o2_sensor_mv2']),
    o2SensorMv3: intOf(data['o2_sensor_mv3']),
    o2SensorMv4: intOf(data['o2_sensor_mv4']),
    o2SensorMv5: intOf(data['o2_sensor_mv5']),
    o2SensorMv6: intOf(data['o2_sensor_mv6']),
  );
}

/// One OPTIONAL sample field, or null when the stored value is not a number.
///
/// SQLite carries a storage class per value, not per column, so a
/// REAL-affinity column in a restored or hand-repaired file can hold text it
/// could not convert. A cast would throw, and the packer's isolation is
/// per DIVE: one unreadable pressure reading would cost that dive its entire
/// profile, permanently, because nothing reads the legacy tables after v183.
/// Degrading the one field is the proportionate answer. `timestamp` and
/// `depth` above are deliberately NOT read this way: without them there is
/// no sample, so the row is skipped as a whole.
double? realOf(Object? value) => asDoubleOrNull(value);

int? intOf(Object? value) => value is num ? value.toInt() : null;
