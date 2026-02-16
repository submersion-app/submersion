import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';

void main() {
  group('OutlierResult', () {
    test('two OutlierResults with same values are equal', () {
      const a = OutlierResult(
        index: 5,
        timestamp: 60,
        depth: 15.0,
        depthDelta: 8.0,
        zScore: 4.5,
      );
      const b = OutlierResult(
        index: 5,
        timestamp: 60,
        depth: 15.0,
        depthDelta: 8.0,
        zScore: 4.5,
      );
      expect(a, equals(b));
    });

    test('two OutlierResults with different values are not equal', () {
      const a = OutlierResult(
        index: 5,
        timestamp: 60,
        depth: 15.0,
        depthDelta: 8.0,
        zScore: 4.5,
      );
      const b = OutlierResult(
        index: 6,
        timestamp: 60,
        depth: 15.0,
        depthDelta: 8.0,
        zScore: 4.5,
      );
      expect(a, isNot(equals(b)));
    });

    test('isPhysicallyImpossible defaults to false', () {
      const r = OutlierResult(
        index: 0,
        timestamp: 0,
        depth: 0,
        depthDelta: 0,
        zScore: 0,
      );
      expect(r.isPhysicallyImpossible, isFalse);
    });

    test('isPhysicallyImpossible can be set to true', () {
      const r = OutlierResult(
        index: 3,
        timestamp: 30,
        depth: 25.0,
        depthDelta: 12.0,
        zScore: 6.0,
        isPhysicallyImpossible: true,
      );
      expect(r.isPhysicallyImpossible, isTrue);
    });

    test('props includes all fields', () {
      const r = OutlierResult(
        index: 1,
        timestamp: 10,
        depth: 5.0,
        depthDelta: 3.0,
        zScore: 2.0,
        isPhysicallyImpossible: true,
      );
      expect(r.props, [1, 10, 5.0, 3.0, 2.0, true]);
    });

    test('equality accounts for isPhysicallyImpossible flag', () {
      const a = OutlierResult(
        index: 5,
        timestamp: 60,
        depth: 15.0,
        depthDelta: 8.0,
        zScore: 4.5,
      );
      const b = OutlierResult(
        index: 5,
        timestamp: 60,
        depth: 15.0,
        depthDelta: 8.0,
        zScore: 4.5,
        isPhysicallyImpossible: true,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
