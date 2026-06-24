import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';

void main() {
  group('MetricDataSource', () {
    test('toInt returns 0 for computer, 1 for calculated', () {
      expect(MetricDataSource.computer.toInt(), 0);
      expect(MetricDataSource.calculated.toInt(), 1);
    });

    test('fromInt returns computer for 0', () {
      expect(MetricDataSource.fromInt(0), MetricDataSource.computer);
    });

    test('fromInt returns calculated for 1', () {
      expect(MetricDataSource.fromInt(1), MetricDataSource.calculated);
    });

    test('fromInt defaults to calculated for unknown values', () {
      expect(MetricDataSource.fromInt(99), MetricDataSource.calculated);
      expect(MetricDataSource.fromInt(-1), MetricDataSource.calculated);
    });

    test('roundtrip: toInt then fromInt', () {
      for (final source in MetricDataSource.values) {
        expect(MetricDataSource.fromInt(source.toInt()), source);
      }
    });
  });

  group('MetricSourceInfo', () {
    test('can be created with all fields', () {
      const info = (
        ndlActual: MetricDataSource.computer,
        ceilingActual: MetricDataSource.calculated,
        ttsActual: MetricDataSource.computer,
        cnsActual: MetricDataSource.calculated,
      );
      expect(info.ndlActual, MetricDataSource.computer);
      expect(info.ceilingActual, MetricDataSource.calculated);
      expect(info.ttsActual, MetricDataSource.computer);
      expect(info.cnsActual, MetricDataSource.calculated);
    });

    test('all-calculated convenience works', () {
      const info = (
        ndlActual: MetricDataSource.calculated,
        ceilingActual: MetricDataSource.calculated,
        ttsActual: MetricDataSource.calculated,
        cnsActual: MetricDataSource.calculated,
      );
      expect(info.ndlActual, MetricDataSource.calculated);
    });
  });

  group('ProfileRightAxisMetric.ascentRate', () {
    test('has expected display metadata', () {
      const metric = ProfileRightAxisMetric.ascentRate;
      expect(metric.displayName, 'Ascent Rate');
      expect(metric.shortName, 'Rate');
      expect(metric.category, ProfileMetricCategory.primary);
    });

    test('is excluded from the auto fallback chain', () {
      // Ascent rate must never auto-claim the right axis; it is opt-in only.
      expect(
        ProfileRightAxisMetric.fallbackPriority,
        isNot(contains(ProfileRightAxisMetric.ascentRate)),
      );
    });
  });
}
