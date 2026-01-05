import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('AscentRateCalculator', () {
    late AscentRateCalculator calculator;

    setUp(() {
      calculator = const AscentRateCalculator();
    });

    group('calculateRate (static)', () {
      test('should return 0 for same depth', () {
        expect(AscentRateCalculator.calculateRate(20, 20, 0, 60), equals(0.0));
      });

      test('should return 0 for same timestamp', () {
        expect(AscentRateCalculator.calculateRate(20, 10, 60, 60), equals(0.0));
      });

      test('should calculate positive rate for ascent', () {
        // Going from 20m to 10m in 60 seconds = 10m/min
        final rate = AscentRateCalculator.calculateRate(20, 10, 0, 60);
        expect(rate, closeTo(10.0, 0.01));
      });

      test('should calculate negative rate for descent', () {
        // Going from 10m to 20m in 60 seconds = -10m/min
        final rate = AscentRateCalculator.calculateRate(10, 20, 0, 60);
        expect(rate, closeTo(-10.0, 0.01));
      });

      test('should calculate 9m/min ascent correctly', () {
        // Going from 18m to 9m in 60 seconds = 9m/min
        final rate = AscentRateCalculator.calculateRate(18, 9, 0, 60);
        expect(rate, closeTo(9.0, 0.01));
      });

      test('should handle 2 minute intervals', () {
        // Going from 30m to 10m in 2 minutes = 10m/min
        final rate = AscentRateCalculator.calculateRate(30, 10, 0, 120);
        expect(rate, closeTo(10.0, 0.01));
      });

      test('should handle short intervals', () {
        // Going from 10m to 9m in 10 seconds = 6m/min
        final rate = AscentRateCalculator.calculateRate(10, 9, 0, 10);
        expect(rate, closeTo(6.0, 0.01));
      });
    });

    group('categorize', () {
      test('should return safe for slow ascent', () {
        expect(calculator.categorize(5.0), equals(AscentRateCategory.safe));
        expect(calculator.categorize(8.0), equals(AscentRateCategory.safe));
        expect(calculator.categorize(9.0), equals(AscentRateCategory.safe));
      });

      test('should return safe for descent', () {
        expect(calculator.categorize(-5.0), equals(AscentRateCategory.safe));
        expect(calculator.categorize(-9.0), equals(AscentRateCategory.safe));
      });

      test('should return warning for elevated ascent', () {
        expect(calculator.categorize(9.1), equals(AscentRateCategory.warning));
        expect(calculator.categorize(10.0), equals(AscentRateCategory.warning));
        expect(calculator.categorize(12.0), equals(AscentRateCategory.warning));
      });

      test('should return danger for fast ascent', () {
        expect(calculator.categorize(12.1), equals(AscentRateCategory.danger));
        expect(calculator.categorize(15.0), equals(AscentRateCategory.danger));
        expect(calculator.categorize(20.0), equals(AscentRateCategory.danger));
      });

      test('should categorize descent by absolute value', () {
        // Fast descent also triggers warnings
        expect(
          calculator.categorize(-10.0),
          equals(AscentRateCategory.warning),
        );
        expect(calculator.categorize(-15.0), equals(AscentRateCategory.danger));
      });

      test('should respect custom thresholds', () {
        const conservative = AscentRateCalculator(
          warningThreshold: 6.0,
          criticalThreshold: 9.0,
        );

        expect(
          conservative.categorize(7.0),
          equals(AscentRateCategory.warning),
        );
        expect(
          conservative.categorize(10.0),
          equals(AscentRateCategory.danger),
        );
        expect(calculator.categorize(7.0), equals(AscentRateCategory.safe));
      });
    });

    group('calculateProfileRates', () {
      test('should handle empty profile', () {
        final rates = calculator.calculateProfileRates([], []);
        expect(rates, isEmpty);
      });

      test('should handle mismatched arrays', () {
        final rates = calculator.calculateProfileRates([10, 20, 30], [0, 60]);
        expect(rates, isEmpty);
      });

      test('should handle single point', () {
        final rates = calculator.calculateProfileRates([10], [0]);
        expect(rates.length, equals(1));
        expect(rates[0].rateMetersPerMin, equals(0.0));
        expect(rates[0].category, equals(AscentRateCategory.safe));
      });

      test('should calculate rates for simple profile', () {
        // Descent to 30m, stay, ascent
        final depths = [0.0, 15.0, 30.0, 30.0, 15.0, 0.0];
        final timestamps = [0, 60, 120, 600, 660, 720];

        // Use no smoothing for predictable results
        const calc = AscentRateCalculator(smoothingWindow: 1);
        final rates = calc.calculateProfileRates(depths, timestamps);

        expect(rates.length, equals(6));

        // First point has no prior rate
        expect(rates[0].rateMetersPerMin, equals(0.0));

        // Descent points should have negative rates (-15m/min)
        expect(rates[1].rateMetersPerMin, closeTo(-15.0, 0.1));
        expect(rates[2].rateMetersPerMin, closeTo(-15.0, 0.1));

        // Bottom time should have near-zero rate
        expect(rates[3].rateMetersPerMin, closeTo(0.0, 0.1));

        // Ascent points should have positive rates (15m/min)
        expect(rates[4].rateMetersPerMin, closeTo(15.0, 0.1));
        expect(rates[5].rateMetersPerMin, closeTo(15.0, 0.1));
      });

      test('should identify safe ascent rate', () {
        // Slow ascent: 10m to 0m in 2 minutes = 5m/min
        final depths = [10.0, 5.0, 0.0];
        final timestamps = [0, 60, 120];

        final rates = calculator.calculateProfileRates(depths, timestamps);

        // Both ascent points should be safe
        expect(rates[1].category, equals(AscentRateCategory.safe));
        expect(rates[2].category, equals(AscentRateCategory.safe));
      });

      test('should identify warning ascent rate', () {
        // Fast ascent: 30m to 0m in 3 minutes = 10m/min
        final depths = [30.0, 20.0, 10.0, 0.0];
        final timestamps = [0, 60, 120, 180];

        // Use no smoothing for predictable results
        const calc = AscentRateCalculator(smoothingWindow: 1);
        final rates = calc.calculateProfileRates(depths, timestamps);

        // Ascent rates of 10m/min should be warning
        for (int i = 1; i < rates.length; i++) {
          expect(rates[i].category, equals(AscentRateCategory.warning));
        }
      });

      test('should identify dangerous ascent rate', () {
        // Very fast ascent: 30m to 0m in 1 minute = 30m/min
        final depths = [30.0, 0.0];
        final timestamps = [0, 60];

        const calc = AscentRateCalculator(smoothingWindow: 1);
        final rates = calc.calculateProfileRates(depths, timestamps);

        expect(rates[1].category, equals(AscentRateCategory.danger));
        expect(rates[1].rateMetersPerMin, closeTo(30.0, 0.1));
      });

      test('should smooth rates when window > 1', () {
        // Create a profile with one spike
        final depths = [30.0, 30.0, 25.0, 30.0, 30.0];
        final timestamps = [0, 60, 70, 80, 140];

        const smoothedCalc = AscentRateCalculator(smoothingWindow: 3);
        const unsmoothCalc = AscentRateCalculator(smoothingWindow: 1);

        final smoothed = smoothedCalc.calculateProfileRates(depths, timestamps);
        final unsmooth = unsmoothCalc.calculateProfileRates(depths, timestamps);

        // With smoothing, spike should be reduced
        expect(
          smoothed[2].rateMetersPerMin.abs(),
          lessThan(unsmooth[2].rateMetersPerMin.abs()),
        );
      });
    });

    group('findViolations', () {
      test('should find no violations in safe dive', () {
        // Slow descent and ascent
        final depths = [0.0, 20.0, 20.0, 0.0];
        final timestamps = [0, 240, 1200, 1440]; // 4 min descent, 4 min ascent

        final rates = calculator.calculateProfileRates(depths, timestamps);
        final violations = calculator.findViolations(rates);

        expect(violations, isEmpty);
      });

      test('should find single violation', () {
        // One fast ascent section
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 25,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 20,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 90,
            depth: 15,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
        ];

        final violations = calculator.findViolations(rates);

        expect(violations.length, equals(1));
        expect(violations[0].startTimestamp, equals(30));
        expect(violations[0].endTimestamp, equals(60));
        expect(violations[0].maxRate, equals(10));
        expect(violations[0].isCritical, isFalse);
      });

      test('should find multiple violations', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 25,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 22,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 90,
            depth: 10,
            rateMetersPerMin: 15,
            category: AscentRateCategory.danger,
          ),
          const AscentRatePoint(
            timestamp: 120,
            depth: 5,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
        ];

        final violations = calculator.findViolations(rates);

        expect(violations.length, equals(2));
        expect(violations[0].isCritical, isFalse);
        expect(violations[1].isCritical, isTrue);
      });

      test('should track critical violations', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 20,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 45,
            depth: 10,
            rateMetersPerMin: 20,
            category: AscentRateCategory.danger,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 5,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 90,
            depth: 0,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
        ];

        final violations = calculator.findViolations(rates);

        expect(violations.length, equals(1));
        expect(violations[0].isCritical, isTrue);
        expect(violations[0].maxRate, equals(20));
        expect(violations[0].depthAtMaxRate, equals(10));
      });

      test('should handle violation at end of dive', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 20,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 10,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 0,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
        ];

        final violations = calculator.findViolations(rates);

        expect(violations.length, equals(1));
        expect(violations[0].startTimestamp, equals(30));
        expect(violations[0].endTimestamp, equals(60));
      });
    });

    group('getMaxAscentRate', () {
      test('should return 0 for empty list', () {
        expect(calculator.getMaxAscentRate([]), equals(0.0));
      });

      test('should find maximum ascent rate', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 25,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 10,
            rateMetersPerMin: 30,
            category: AscentRateCategory.danger,
          ),
          const AscentRatePoint(
            timestamp: 90,
            depth: 5,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
        ];

        expect(calculator.getMaxAscentRate(rates), equals(30.0));
      });

      test('should ignore descent rates', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 0,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 30,
            rateMetersPerMin: -30,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 120,
            depth: 25,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
        ];

        expect(calculator.getMaxAscentRate(rates), equals(5.0));
      });
    });

    group('getMaxDescentRate', () {
      test('should return 0 for empty list', () {
        expect(calculator.getMaxDescentRate([]), equals(0.0));
      });

      test('should find maximum descent rate', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 0,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 30,
            rateMetersPerMin: -30,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 120,
            depth: 40,
            rateMetersPerMin: -10,
            category: AscentRateCategory.safe,
          ),
        ];

        expect(
          calculator.getMaxDescentRate(rates),
          equals(30.0),
        ); // Returned as positive
      });

      test('should ignore ascent rates', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: -5,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 10,
            rateMetersPerMin: 30,
            category: AscentRateCategory.safe,
          ),
        ];

        expect(calculator.getMaxDescentRate(rates), equals(5.0));
      });
    });

    group('getStats', () {
      test('should return zero stats for empty list', () {
        final stats = calculator.getStats([]);

        expect(stats.maxAscentRate, equals(0));
        expect(stats.maxDescentRate, equals(0));
        expect(stats.averageAscentRate, equals(0));
        expect(stats.averageDescentRate, equals(0));
        expect(stats.violationCount, equals(0));
        expect(stats.criticalViolationCount, equals(0));
        expect(stats.timeInViolation, equals(0));
      });

      test('should calculate correct stats for dive', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 0,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 30,
            rateMetersPerMin: -30,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 600,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 660,
            depth: 20,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 720,
            depth: 10,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 780,
            depth: 0,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
        ];

        final stats = calculator.getStats(rates);

        expect(stats.maxAscentRate, equals(10.0));
        expect(stats.maxDescentRate, equals(30.0));
        expect(stats.violationCount, equals(1));
        expect(stats.criticalViolationCount, equals(0));
        expect(stats.hasViolations, isTrue);
        expect(stats.hasCriticalViolations, isFalse);
      });

      test('should count critical violations', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 15,
            rateMetersPerMin: 30,
            category: AscentRateCategory.danger,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 0,
            rateMetersPerMin: 30,
            category: AscentRateCategory.danger,
          ),
        ];

        final stats = calculator.getStats(rates);

        expect(stats.criticalViolationCount, equals(1));
        expect(stats.hasCriticalViolations, isTrue);
      });

      test('should calculate average rates correctly', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 0,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 20,
            rateMetersPerMin: -20,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 120,
            depth: 30,
            rateMetersPerMin: -10,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 300,
            depth: 20,
            rateMetersPerMin: 6,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 480,
            depth: 10,
            rateMetersPerMin: 6,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 660,
            depth: 0,
            rateMetersPerMin: 6,
            category: AscentRateCategory.safe,
          ),
        ];

        final stats = calculator.getStats(rates);

        // Average descent: (20 + 10) / 2 = 15
        expect(stats.averageDescentRate, closeTo(15.0, 0.1));
        // Average ascent: (6 + 6 + 6) / 3 = 6
        expect(stats.averageAscentRate, closeTo(6.0, 0.1));
      });

      test('should calculate time in violation', () {
        final rates = [
          const AscentRatePoint(
            timestamp: 0,
            depth: 30,
            rateMetersPerMin: 0,
            category: AscentRateCategory.safe,
          ),
          const AscentRatePoint(
            timestamp: 30,
            depth: 20,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 60,
            depth: 10,
            rateMetersPerMin: 10,
            category: AscentRateCategory.warning,
          ),
          const AscentRatePoint(
            timestamp: 90,
            depth: 0,
            rateMetersPerMin: 5,
            category: AscentRateCategory.safe,
          ),
        ];

        final stats = calculator.getStats(rates);

        // Violation from t=30 to t=60 = 30 seconds
        expect(stats.timeInViolation, equals(30));
      });
    });
  });

  group('AscentRatePoint', () {
    test('should identify descending state', () {
      const point = AscentRatePoint(
        timestamp: 0,
        depth: 10,
        rateMetersPerMin: -15,
        category: AscentRateCategory.safe,
      );
      expect(point.isDescending, isTrue);
      expect(point.isAscending, isFalse);
      expect(point.isConstant, isFalse);
    });

    test('should identify ascending state', () {
      const point = AscentRatePoint(
        timestamp: 0,
        depth: 10,
        rateMetersPerMin: 8,
        category: AscentRateCategory.safe,
      );
      expect(point.isDescending, isFalse);
      expect(point.isAscending, isTrue);
      expect(point.isConstant, isFalse);
    });

    test('should identify constant depth', () {
      const point = AscentRatePoint(
        timestamp: 0,
        depth: 10,
        rateMetersPerMin: 0.2,
        category: AscentRateCategory.safe,
      );
      expect(point.isConstant, isTrue);
    });

    test('should format rate correctly', () {
      const ascending = AscentRatePoint(
        timestamp: 0,
        depth: 10,
        rateMetersPerMin: 8.5,
        category: AscentRateCategory.safe,
      );
      expect(ascending.rateFormatted, equals('+8.5 m/min'));

      const descending = AscentRatePoint(
        timestamp: 0,
        depth: 10,
        rateMetersPerMin: -15.0,
        category: AscentRateCategory.safe,
      );
      expect(descending.rateFormatted, equals('-15.0 m/min'));

      const constant = AscentRatePoint(
        timestamp: 0,
        depth: 10,
        rateMetersPerMin: 0.3,
        category: AscentRateCategory.safe,
      );
      expect(constant.rateFormatted, equals('0 m/min'));
    });
  });

  group('AscentRateViolation', () {
    test('should calculate duration correctly', () {
      const violation = AscentRateViolation(
        startTimestamp: 100,
        endTimestamp: 160,
        maxRate: 15,
        depthAtMaxRate: 20,
        isCritical: false,
      );
      expect(violation.durationSeconds, equals(60));
    });

    test('should format short duration', () {
      const violation = AscentRateViolation(
        startTimestamp: 0,
        endTimestamp: 45,
        maxRate: 15,
        depthAtMaxRate: 20,
        isCritical: false,
      );
      expect(violation.durationFormatted, equals('45s'));
    });

    test('should format long duration', () {
      const violation = AscentRateViolation(
        startTimestamp: 0,
        endTimestamp: 90,
        maxRate: 15,
        depthAtMaxRate: 20,
        isCritical: true,
      );
      expect(violation.durationFormatted, equals('1m 30s'));
    });
  });

  group('AscentRateStats', () {
    test('should identify violations correctly', () {
      const withViolations = AscentRateStats(
        maxAscentRate: 15,
        maxDescentRate: 20,
        averageAscentRate: 8,
        averageDescentRate: 15,
        violationCount: 2,
        criticalViolationCount: 1,
        timeInViolation: 60,
      );
      expect(withViolations.hasViolations, isTrue);
      expect(withViolations.hasCriticalViolations, isTrue);

      const noViolations = AscentRateStats(
        maxAscentRate: 8,
        maxDescentRate: 20,
        averageAscentRate: 6,
        averageDescentRate: 15,
        violationCount: 0,
        criticalViolationCount: 0,
        timeInViolation: 0,
      );
      expect(noViolations.hasViolations, isFalse);
      expect(noViolations.hasCriticalViolations, isFalse);
    });
  });

  group('Integration tests', () {
    test('should analyze a typical recreational dive profile', () {
      const calculator = AscentRateCalculator(smoothingWindow: 1);

      // Simulate a 30-minute dive to 18m with proper ascent
      final depths = <double>[];
      final timestamps = <int>[];

      // Descent: 0 to 18m in 1.5 min (12m/min)
      for (int t = 0; t <= 90; t += 10) {
        timestamps.add(t);
        depths.add(t * 0.2); // 12m/min descent
      }

      // Bottom time: 25 minutes at 18m
      for (int t = 100; t <= 1500; t += 60) {
        timestamps.add(t);
        depths.add(18.0);
      }

      // Ascent: 18m to 5m at 9m/min (safe)
      for (int t = 1510; t <= 1596; t += 10) {
        timestamps.add(t);
        depths.add(18.0 - ((t - 1500) / 60.0) * 9);
      }

      // Safety stop: 3 min at 5m
      for (int t = 1600; t <= 1780; t += 60) {
        timestamps.add(t);
        depths.add(5.0);
      }

      // Final ascent: 5m to 0m in 1 min
      timestamps.add(1840);
      depths.add(0.0);

      final rates = calculator.calculateProfileRates(depths, timestamps);
      final stats = calculator.getStats(rates);

      // Should have some warning for descent (12m/min descent)
      // Ascent at 9m/min is exactly at threshold
      expect(stats.maxDescentRate, greaterThanOrEqualTo(10));
      expect(stats.maxAscentRate, lessThanOrEqualTo(12));
    });

    test('should detect emergency ascent', () {
      const calculator = AscentRateCalculator(smoothingWindow: 1);

      // Emergency ascent from 30m to surface in 1 minute (30m/min!)
      final depths = [30.0, 20.0, 10.0, 0.0];
      final timestamps = [0, 20, 40, 60];

      final rates = calculator.calculateProfileRates(depths, timestamps);
      final violations = calculator.findViolations(rates);
      final stats = calculator.getStats(rates);

      expect(violations.isNotEmpty, isTrue);
      expect(stats.hasCriticalViolations, isTrue);
      expect(stats.maxAscentRate, closeTo(30.0, 1.0));
    });
  });
}
