import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Conversions between the codec's [ProfileSample] and the domain
/// [DiveProfilePoint]. Kept out of `profile_sample.dart` so the codec files,
/// and through them `database.dart`, never import the entity graph (which
/// reaches Flutter through `tag.dart`).
extension ProfileSampleToPoint on ProfileSample {
  /// The domain point. Drops [ProfileSample.pressure], which
  /// [DiveProfilePoint] does not carry.
  DiveProfilePoint toPoint() {
    return DiveProfilePoint(
      timestamp: timestamp,
      depth: depth,
      temperature: temperature,
      heartRate: heartRate,
      heading: heading,
      setpoint: setpoint,
      ppO2: ppO2,
      o2Sensor1: o2Sensor1,
      o2Sensor2: o2Sensor2,
      o2Sensor3: o2Sensor3,
      o2Sensor4: o2Sensor4,
      o2Sensor5: o2Sensor5,
      o2Sensor6: o2Sensor6,
      o2SensorMv1: o2SensorMv1,
      o2SensorMv2: o2SensorMv2,
      o2SensorMv3: o2SensorMv3,
      o2SensorMv4: o2SensorMv4,
      o2SensorMv5: o2SensorMv5,
      o2SensorMv6: o2SensorMv6,
      heartRateSource: heartRateSource,
      cns: cns,
      ndl: ndl,
      ceiling: ceiling,
      ascentRate: ascentRate,
      rbt: rbt,
      decoType: decoType,
      tts: tts,
    );
  }
}

/// [ProfileSample] from a domain point, with the legacy per-sample
/// [pressure] supplied separately.
ProfileSample profileSampleFromPoint(
  DiveProfilePoint point, {
  double? pressure,
}) {
  return ProfileSample(
    timestamp: point.timestamp,
    depth: point.depth,
    pressure: pressure,
    temperature: point.temperature,
    heartRate: point.heartRate,
    ascentRate: point.ascentRate,
    ceiling: point.ceiling,
    ndl: point.ndl,
    setpoint: point.setpoint,
    ppO2: point.ppO2,
    o2Sensor1: point.o2Sensor1,
    o2Sensor2: point.o2Sensor2,
    o2Sensor3: point.o2Sensor3,
    o2Sensor4: point.o2Sensor4,
    o2Sensor5: point.o2Sensor5,
    o2Sensor6: point.o2Sensor6,
    cns: point.cns,
    tts: point.tts,
    rbt: point.rbt,
    decoType: point.decoType,
    heartRateSource: point.heartRateSource,
    heading: point.heading,
    o2SensorMv1: point.o2SensorMv1,
    o2SensorMv2: point.o2SensorMv2,
    o2SensorMv3: point.o2SensorMv3,
    o2SensorMv4: point.o2SensorMv4,
    o2SensorMv5: point.o2SensorMv5,
    o2SensorMv6: point.o2SensorMv6,
  );
}
