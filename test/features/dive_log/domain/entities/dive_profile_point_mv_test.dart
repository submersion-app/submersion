import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveProfilePoint O2 cell millivolts', () {
    test('carries per-cell millivolts', () {
      const p = DiveProfilePoint(
        timestamp: 60,
        depth: 12.5,
        o2SensorMv1: 58,
        o2SensorMv2: 61,
        o2SensorMv3: 43,
      );
      expect(p.o2SensorMv1, 58);
      expect(p.o2SensorMv2, 61);
      expect(p.o2SensorMv3, 43);
      expect(p.o2SensorMv4, isNull);
      expect(p.o2SensorMv5, isNull);
      expect(p.o2SensorMv6, isNull);
    });

    test('millivolts are independent of the per-cell ppO2 values', () {
      // The issue #810 case: the cell reports a measurement but the logged
      // calibration is untrusted, so there is no partial pressure to show.
      const p = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 58);
      expect(p.o2SensorMv1, 58);
      expect(p.o2Sensor1, isNull);
    });

    test('copyWith preserves and overrides millivolts', () {
      const p = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 58);
      expect(p.copyWith(o2SensorMv2: 61).o2SensorMv1, 58);
      expect(p.copyWith(o2SensorMv2: 61).o2SensorMv2, 61);
      expect(p.copyWith(o2SensorMv1: 60).o2SensorMv1, 60);
    });

    test('millivolts participate in equality', () {
      const a = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 58);
      const b = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 61);
      const c = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 58);
      expect(a, isNot(equals(b)));
      expect(a, equals(c));
    });
  });
}
