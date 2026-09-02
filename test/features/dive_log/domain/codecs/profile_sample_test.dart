import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const point = DiveProfilePoint(
    timestamp: 120,
    depth: 18.3,
    temperature: 21.5,
    heartRate: 88,
    heading: 270.0,
    setpoint: 1.2,
    ppO2: 1.19,
    o2Sensor1: 1.18,
    o2Sensor2: 1.2,
    o2Sensor3: 1.21,
    o2Sensor4: 1.17,
    o2Sensor5: 1.22,
    o2Sensor6: 1.19,
    o2SensorMv1: 51,
    o2SensorMv2: 52,
    o2SensorMv3: 53,
    o2SensorMv4: 50,
    o2SensorMv5: 54,
    o2SensorMv6: 52,
    heartRateSource: 'appleWatch',
    cns: 12.5,
    ndl: 1800,
    ceiling: 3.0,
    ascentRate: -9.0,
    rbt: 1500,
    decoType: 2,
    tts: 900,
  );

  test('fromPoint then toPoint is the identity on every point field', () {
    final sample = profileSampleFromPoint(point);
    expect(sample.toPoint(), point);
  });

  test('fromPoint carries the legacy per-sample pressure separately', () {
    final sample = profileSampleFromPoint(point, pressure: 180.5);
    expect(sample.pressure, 180.5);
    // DiveProfilePoint has no pressure field, so it cannot survive toPoint.
    expect(sample.toPoint(), point);
  });

  test('a minimal point maps with every optional field null', () {
    const minimal = DiveProfilePoint(timestamp: 0, depth: 0.0);
    final sample = profileSampleFromPoint(minimal);
    expect(sample.timestamp, 0);
    expect(sample.depth, 0.0);
    expect(sample.pressure, isNull);
    expect(sample.temperature, isNull);
    expect(sample.heartRateSource, isNull);
    expect(sample.o2SensorMv6, isNull);
    expect(sample.toPoint(), minimal);
  });

  test('value equality covers every field', () {
    final a = profileSampleFromPoint(point, pressure: 1.0);
    final b = profileSampleFromPoint(point, pressure: 1.0);
    final c = profileSampleFromPoint(point, pressure: 2.0);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a.props, hasLength(28));
  });
}
