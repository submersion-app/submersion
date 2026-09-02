import 'package:equatable/equatable.dart';

/// One profile sample exactly as the v181 `dive_profiles` table stored it
/// (the codec's column order), minus the identity columns (`id`, `dive_id`,
/// `computer_id`, `source_id`, `is_primary`) that live on the series row.
///
/// This is the codec's input and output type. It differs from the domain
/// `DiveProfilePoint` in one field: the legacy per-sample [pressure]
/// column, which the v59 migration moved to tank pressure profiles but
/// which older rows still populate. The codec is lossless over the stored
/// row, so the field rides along; the conversion drops it, as every read
/// path does today.
///
/// The conversions to and from `DiveProfilePoint` live in
/// `profile_sample_point.dart`, deliberately: this file is reachable from
/// `database.dart`, and the entity graph reaches Flutter.
class ProfileSample extends Equatable {
  const ProfileSample({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
    this.ascentRate,
    this.ceiling,
    this.ndl,
    this.setpoint,
    this.ppO2,
    this.o2Sensor1,
    this.o2Sensor2,
    this.o2Sensor3,
    this.o2Sensor4,
    this.o2Sensor5,
    this.o2Sensor6,
    this.cns,
    this.tts,
    this.rbt,
    this.decoType,
    this.heartRateSource,
    this.heading,
    this.o2SensorMv1,
    this.o2SensorMv2,
    this.o2SensorMv3,
    this.o2SensorMv4,
    this.o2SensorMv5,
    this.o2SensorMv6,
  });

  /// Seconds from dive start.
  final int timestamp;

  /// Metres.
  final double depth;

  /// Legacy per-sample pressure in bar; null on every row written after the
  /// v59 migration.
  final double? pressure;
  final double? temperature;
  final int? heartRate;
  final double? ascentRate;
  final double? ceiling;
  final int? ndl;
  final double? setpoint;
  final double? ppO2;
  final double? o2Sensor1;
  final double? o2Sensor2;
  final double? o2Sensor3;
  final double? o2Sensor4;
  final double? o2Sensor5;
  final double? o2Sensor6;
  final double? cns;
  final int? tts;
  final int? rbt;
  final int? decoType;
  final String? heartRateSource;
  final double? heading;
  final int? o2SensorMv1;
  final int? o2SensorMv2;
  final int? o2SensorMv3;
  final int? o2SensorMv4;
  final int? o2SensorMv5;
  final int? o2SensorMv6;

  /// The same sample [seconds] later (negative moves it earlier). Merge and
  /// consolidation re-base a segment's samples onto the combined timeline.
  ProfileSample shiftedBy(int seconds) => ProfileSample(
    timestamp: timestamp + seconds,
    depth: depth,
    pressure: pressure,
    temperature: temperature,
    heartRate: heartRate,
    ascentRate: ascentRate,
    ceiling: ceiling,
    ndl: ndl,
    setpoint: setpoint,
    ppO2: ppO2,
    o2Sensor1: o2Sensor1,
    o2Sensor2: o2Sensor2,
    o2Sensor3: o2Sensor3,
    o2Sensor4: o2Sensor4,
    o2Sensor5: o2Sensor5,
    o2Sensor6: o2Sensor6,
    cns: cns,
    tts: tts,
    rbt: rbt,
    decoType: decoType,
    heartRateSource: heartRateSource,
    heading: heading,
    o2SensorMv1: o2SensorMv1,
    o2SensorMv2: o2SensorMv2,
    o2SensorMv3: o2SensorMv3,
    o2SensorMv4: o2SensorMv4,
    o2SensorMv5: o2SensorMv5,
    o2SensorMv6: o2SensorMv6,
  );

  @override
  List<Object?> get props => [
    timestamp,
    depth,
    pressure,
    temperature,
    heartRate,
    ascentRate,
    ceiling,
    ndl,
    setpoint,
    ppO2,
    o2Sensor1,
    o2Sensor2,
    o2Sensor3,
    o2Sensor4,
    o2Sensor5,
    o2Sensor6,
    cns,
    tts,
    rbt,
    decoType,
    heartRateSource,
    heading,
    o2SensorMv1,
    o2SensorMv2,
    o2SensorMv3,
    o2SensorMv4,
    o2SensorMv5,
    o2SensorMv6,
  ];
}
