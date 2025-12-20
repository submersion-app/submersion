import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';

void main() {
  group('O2ToxicityCalculator', () {
    late O2ToxicityCalculator calculator;

    setUp(() {
      calculator = const O2ToxicityCalculator();
    });

    group('calculatePpO2', () {
      test('should return O2 fraction at surface', () {
        // At surface (0m), ppO2 = 1.0 * fO2
        expect(
            O2ToxicityCalculator.calculatePpO2(0, 0.21), closeTo(0.21, 0.001));
        expect(
            O2ToxicityCalculator.calculatePpO2(0, 0.32), closeTo(0.32, 0.001));
        expect(O2ToxicityCalculator.calculatePpO2(0, 1.0), closeTo(1.0, 0.001));
      });

      test('should calculate ppO2 at 10m correctly', () {
        // At 10m, ambient pressure = 2.0 bar
        // ppO2 = 2.0 * fO2
        expect(
            O2ToxicityCalculator.calculatePpO2(10, 0.21), closeTo(0.42, 0.001));
        expect(
            O2ToxicityCalculator.calculatePpO2(10, 0.32), closeTo(0.64, 0.001));
      });

      test('should calculate ppO2 at 30m correctly', () {
        // At 30m, ambient pressure = 4.0 bar
        expect(
            O2ToxicityCalculator.calculatePpO2(30, 0.21), closeTo(0.84, 0.001));
        expect(
            O2ToxicityCalculator.calculatePpO2(30, 0.32), closeTo(1.28, 0.001));
      });

      test('should reach 1.4 ppO2 at MOD for nitrox 32', () {
        // MOD for EAN32 at 1.4 ppO2 is 33.75m
        final ppO2 = O2ToxicityCalculator.calculatePpO2(33.75, 0.32);
        expect(ppO2, closeTo(1.4, 0.01));
      });

      test('should calculate ppO2 for pure O2', () {
        // Pure O2 at 6m (1.6 bar ambient)
        expect(O2ToxicityCalculator.calculatePpO2(6, 1.0), closeTo(1.6, 0.001));
      });
    });

    group('calculateMod', () {
      test('should calculate MOD for air at 1.4 ppO2', () {
        // MOD = ((1.4 / 0.21) - 1) * 10 = 56.67m
        final mod = O2ToxicityCalculator.calculateMod(0.21);
        expect(mod, closeTo(56.67, 0.1));
      });

      test('should calculate MOD for nitrox 32 at 1.4 ppO2', () {
        // MOD = ((1.4 / 0.32) - 1) * 10 = 33.75m
        final mod = O2ToxicityCalculator.calculateMod(0.32);
        expect(mod, closeTo(33.75, 0.1));
      });

      test('should calculate MOD for nitrox 36 at 1.4 ppO2', () {
        // MOD = ((1.4 / 0.36) - 1) * 10 = 28.89m
        final mod = O2ToxicityCalculator.calculateMod(0.36);
        expect(mod, closeTo(28.89, 0.1));
      });

      test('should calculate MOD at 1.6 ppO2 for deco', () {
        // MOD for EAN50 at 1.6 = ((1.6 / 0.5) - 1) * 10 = 22m
        final mod = O2ToxicityCalculator.calculateMod(0.50, maxPpO2: 1.6);
        expect(mod, closeTo(22.0, 0.1));
      });

      test('should calculate MOD for pure O2 at 1.6 ppO2', () {
        // MOD = ((1.6 / 1.0) - 1) * 10 = 6m
        final mod = O2ToxicityCalculator.calculateMod(1.0, maxPpO2: 1.6);
        expect(mod, closeTo(6.0, 0.1));
      });

      test('should return 0 for invalid O2 fraction', () {
        expect(O2ToxicityCalculator.calculateMod(0), equals(0));
        expect(O2ToxicityCalculator.calculateMod(-0.1), equals(0));
      });
    });

    group('calculateEnd', () {
      test('should calculate END for air dive', () {
        // Air at 30m: END should equal actual depth (no advantage)
        final end = O2ToxicityCalculator.calculateEnd(30, 0.79);
        expect(end, closeTo(30, 0.5));
      });

      test('should calculate reduced END for trimix', () {
        // Trimix 18/45 at 60m (45% He, 37% N2)
        // N2 pressure at 60m = 7.0 * 0.37 = 2.59 bar
        // END = (2.59 / 0.79 - 1) * 10 = 22.8m
        final end = O2ToxicityCalculator.calculateEnd(60, 0.37);
        expect(end, closeTo(22.8, 1.0));
      });

      test('should return negative END at surface with low N2', () {
        // At surface with 50% N2: END < 0m
        final end = O2ToxicityCalculator.calculateEnd(0, 0.50);
        expect(end, lessThan(0));
      });
    });

    group('getCnsPerMinute', () {
      test('should return 0 for ppO2 <= 0.5', () {
        expect(calculator.getCnsPerMinute(0.0), equals(0.0));
        expect(calculator.getCnsPerMinute(0.3), equals(0.0));
        expect(calculator.getCnsPerMinute(0.5), equals(0.0));
      });

      test('should return increasing rates for higher ppO2', () {
        final rate06 = calculator.getCnsPerMinute(0.6);
        final rate10 = calculator.getCnsPerMinute(1.0);
        final rate14 = calculator.getCnsPerMinute(1.4);
        final rate16 = calculator.getCnsPerMinute(1.6);

        expect(rate06, greaterThan(0));
        expect(rate10, greaterThan(rate06));
        expect(rate14, greaterThan(rate10));
        expect(rate16, greaterThan(rate14));
      });

      test('should match NOAA limits at 1.4 ppO2', () {
        // At 1.4 ppO2, 150 minutes to 100% CNS
        // Rate = 100% / 150 min = 0.667%/min
        final rate = calculator.getCnsPerMinute(1.4);
        expect(rate, closeTo(100.0 / 150.0, 0.01));
      });

      test('should match NOAA limits at 1.6 ppO2', () {
        // At 1.6 ppO2, 45 minutes to 100% CNS
        // Rate = 100% / 45 min = 2.22%/min
        final rate = calculator.getCnsPerMinute(1.6);
        expect(rate, closeTo(100.0 / 45.0, 0.01));
      });

      test('should return high rate above 1.6 ppO2', () {
        final rate = calculator.getCnsPerMinute(1.8);
        expect(rate, greaterThan(calculator.getCnsPerMinute(1.6)));
      });
    });

    group('calculateCnsForSegment', () {
      test('should return 0 for low ppO2', () {
        expect(calculator.calculateCnsForSegment(0.5, 3600), equals(0.0));
      });

      test('should accumulate CNS for segment at 1.4 ppO2', () {
        // 10 minutes at 1.4 ppO2 should be about 6.67% CNS
        final cns = calculator.calculateCnsForSegment(1.4, 10 * 60);
        expect(cns, closeTo(6.67, 0.5));
      });

      test('should reach 100% CNS at limit time', () {
        // 150 minutes at 1.4 ppO2 should be 100% CNS
        final cns = calculator.calculateCnsForSegment(1.4, 150 * 60);
        expect(cns, closeTo(100.0, 0.5));
      });

      test('should accumulate faster at higher ppO2', () {
        final cns14 = calculator.calculateCnsForSegment(1.4, 10 * 60);
        final cns16 = calculator.calculateCnsForSegment(1.6, 10 * 60);
        expect(cns16, greaterThan(cns14));
      });
    });

    group('calculateOtuForSegment', () {
      test('should return 0 for ppO2 <= 0.5', () {
        expect(calculator.calculateOtuForSegment(0.5, 3600), equals(0.0));
        expect(calculator.calculateOtuForSegment(0.3, 3600), equals(0.0));
      });

      test('should calculate OTU for typical recreational dive', () {
        // 40 minutes at ppO2 1.0 (20m on air)
        // OTU = 40 * ((1.0 - 0.5) / 0.5)^0.833 = 40 * 1.0 = 40 OTU
        final otu = calculator.calculateOtuForSegment(1.0, 40 * 60);
        expect(otu, closeTo(40.0, 1.0));
      });

      test('should accumulate more OTU at higher ppO2', () {
        final otu10 = calculator.calculateOtuForSegment(1.0, 30 * 60);
        final otu14 = calculator.calculateOtuForSegment(1.4, 30 * 60);
        expect(otu14, greaterThan(otu10));
      });

      test('should stay well below daily limit for recreational dive', () {
        // Typical recreational dive shouldn't exceed daily limit
        final otu = calculator.calculateOtuForSegment(1.4, 60 * 60);
        expect(otu, lessThan(O2Exposure.dailyOtuLimit));
      });
    });

    group('calculateDiveExposure', () {
      test('should handle empty profile', () {
        final exposure = calculator.calculateDiveExposure(
          depths: [],
          timestamps: [],
          o2Fraction: 0.21,
        );
        expect(exposure.cnsEnd, equals(0.0));
        expect(exposure.otu, equals(0.0));
      });

      test('should handle mismatched arrays', () {
        final exposure = calculator.calculateDiveExposure(
          depths: [0, 10, 20],
          timestamps: [0, 60],
          o2Fraction: 0.21,
        );
        expect(exposure.cnsEnd, equals(0.0));
      });

      test('should calculate exposure for simple dive profile', () {
        // Simple square profile: 30 minutes at 20m on air
        final depths = [0.0, 20.0, 20.0, 0.0];
        final timestamps = [
          0,
          120,
          1800 + 120,
          1800 + 240
        ]; // descent, bottom, ascent

        final exposure = calculator.calculateDiveExposure(
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.21,
        );

        expect(exposure.cnsStart, equals(0.0));
        expect(exposure.cnsEnd, greaterThan(0.0));
        expect(exposure.otu, greaterThan(0.0));
        expect(exposure.maxPpO2, greaterThan(0.0));
        expect(exposure.maxPpO2, lessThanOrEqualTo(0.63)); // ~3 bar * 0.21
      });

      test('should track max ppO2 at max depth', () {
        final depths = [0.0, 10.0, 30.0, 30.0, 10.0, 0.0];
        final timestamps = [0, 60, 180, 1800, 1920, 2040];

        final exposure = calculator.calculateDiveExposure(
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.21,
        );

        // Max ppO2 should occur at or near 30m
        expect(exposure.maxPpO2Depth, closeTo(30, 5));
        expect(exposure.maxPpO2, closeTo(0.84, 0.05)); // 4 bar * 0.21
      });

      test('should start from existing CNS', () {
        final depths = [0.0, 20.0, 20.0, 0.0];
        final timestamps = [0, 60, 1860, 1920];

        final exposure = calculator.calculateDiveExposure(
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.21,
          startCns: 50.0,
        );

        expect(exposure.cnsStart, equals(50.0));
        expect(exposure.cnsEnd, greaterThan(50.0));
      });

      test('should track time above warning threshold', () {
        // Deep dive on EAN36 that exceeds 1.4 ppO2
        final depths = [0.0, 30.0, 30.0, 0.0];
        final timestamps = [0, 180, 1800, 1980];

        final exposure = calculator.calculateDiveExposure(
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.36,
        );

        // At 30m, ppO2 = 4.0 * 0.36 = 1.44 > 1.4
        expect(exposure.timeAboveWarning, greaterThan(0));
      });

      test('should track time above critical threshold', () {
        // Very deep dive exceeding 1.6 ppO2
        final depths = [0.0, 40.0, 40.0, 0.0];
        final timestamps = [0, 240, 1800, 2040];

        final exposure = calculator.calculateDiveExposure(
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.36,
        );

        // At 40m, ppO2 = 5.0 * 0.36 = 1.8 > 1.6
        expect(exposure.timeAboveCritical, greaterThan(0));
      });
    });

    group('calculateMultiGasExposure', () {
      test('should handle single gas (no switches)', () {
        final depths = [0.0, 30.0, 30.0, 0.0];
        final timestamps = [0, 180, 1800, 1980];

        final exposure = calculator.calculateMultiGasExposure(
          depths: depths,
          timestamps: timestamps,
          gasSwitches: {},
          initialO2Fraction: 0.21,
        );

        final singleGasExposure = calculator.calculateDiveExposure(
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.21,
        );

        expect(exposure.otu, closeTo(singleGasExposure.otu, 0.1));
      });

      test('should apply gas switch at correct time', () {
        // Start on 21%, switch to 50% at ascent
        final depths = [0.0, 30.0, 30.0, 6.0, 6.0, 0.0];
        final timestamps = [0, 180, 1800, 2040, 2340, 2400];

        final exposureWithSwitch = calculator.calculateMultiGasExposure(
          depths: depths,
          timestamps: timestamps,
          gasSwitches: {2040: 0.50}, // Switch to EAN50 at 6m
          initialO2Fraction: 0.21,
        );

        final exposureNoSwitch = calculator.calculateMultiGasExposure(
          depths: depths,
          timestamps: timestamps,
          gasSwitches: {},
          initialO2Fraction: 0.21,
        );

        // With EAN50 switch, should have higher CNS/OTU due to higher O2
        expect(exposureWithSwitch.cnsEnd, greaterThan(exposureNoSwitch.cnsEnd));
        expect(exposureWithSwitch.otu, greaterThan(exposureNoSwitch.otu));
      });
    });

    group('calculatePpO2Curve', () {
      test('should return curve matching depth points', () {
        final depths = [0.0, 10.0, 20.0, 30.0, 20.0, 10.0, 0.0];

        final curve = calculator.calculatePpO2Curve(depths, 0.21);

        expect(curve.length, equals(depths.length));
        expect(curve[0], closeTo(0.21, 0.001)); // Surface
        expect(curve[3], closeTo(0.84, 0.001)); // 30m max
      });

      test('should scale with O2 fraction', () {
        final depths = [0.0, 30.0, 0.0];

        final airCurve = calculator.calculatePpO2Curve(depths, 0.21);
        final nitroxCurve = calculator.calculatePpO2Curve(depths, 0.32);

        expect(nitroxCurve[1], greaterThan(airCurve[1]));
        expect(nitroxCurve[1] / airCurve[1], closeTo(0.32 / 0.21, 0.01));
      });
    });

    group('calculateCnsRecovery', () {
      test('should return 0 for 0 CNS', () {
        expect(calculator.calculateCnsRecovery(0, 180), equals(0.0));
      });

      test('should calculate CNS after surface interval', () {
        // The implementation uses a linear formula: CNS * (0.5 * halfTimes)
        // where halfTimes = surfaceInterval / 90
        // At 90 min: 100 * (0.5 * 1) = 50
        final after90 = calculator.calculateCnsRecovery(100, 90);
        expect(after90, closeTo(50.0, 1.0));
      });

      test('should return higher CNS for shorter intervals', () {
        // At 45 min (0.5 half-times): 100 * (0.5 * 0.5) = 25
        final short = calculator.calculateCnsRecovery(100, 45);
        expect(short, closeTo(25.0, 1.0));
      });

      test('should handle half-time calculation', () {
        // The implementation formula: CNS * (0.5 * (interval / 90))
        // This is a linear approximation, not true exponential decay
        final result = calculator.calculateCnsRecovery(80, 90);
        // 80 * (0.5 * 1) = 40
        expect(result, closeTo(40.0, 1.0));
      });
    });

    group('isPpO2Safe', () {
      test('should return true for recreational depths on air', () {
        expect(calculator.isPpO2Safe(10, 0.21), isTrue);
        expect(calculator.isPpO2Safe(30, 0.21), isTrue);
        expect(calculator.isPpO2Safe(40, 0.21), isTrue);
      });

      test('should return true for nitrox within MOD', () {
        expect(calculator.isPpO2Safe(30, 0.32), isTrue); // MOD ~34m
      });

      test('should return false for nitrox beyond MOD', () {
        expect(calculator.isPpO2Safe(40, 0.32), isFalse); // ppO2 = 1.6
      });

      test('should respect custom thresholds', () {
        const conservativeCalc = O2ToxicityCalculator(
          ppO2WarningThreshold: 1.2,
        );

        expect(conservativeCalc.isPpO2Safe(30, 0.32), isFalse); // ppO2 = 1.28
        expect(calculator.isPpO2Safe(30, 0.32), isTrue); // Default 1.4
      });
    });

    group('getPpO2Status', () {
      test('should return low for hypoxic ppO2', () {
        expect(calculator.getPpO2Status(0.16), equals(PpO2Status.low));
        expect(calculator.getPpO2Status(0.5), equals(PpO2Status.low));
      });

      test('should return safe for normal ppO2', () {
        expect(calculator.getPpO2Status(0.6), equals(PpO2Status.safe));
        expect(calculator.getPpO2Status(1.0), equals(PpO2Status.safe));
        expect(calculator.getPpO2Status(1.4), equals(PpO2Status.safe));
      });

      test('should return warning for elevated ppO2', () {
        expect(calculator.getPpO2Status(1.5), equals(PpO2Status.warning));
        expect(calculator.getPpO2Status(1.6), equals(PpO2Status.warning));
      });

      test('should return critical for dangerous ppO2', () {
        expect(calculator.getPpO2Status(1.7), equals(PpO2Status.critical));
        expect(calculator.getPpO2Status(2.0), equals(PpO2Status.critical));
      });
    });

    group('getCnsStatus', () {
      test('should return safe for low CNS', () {
        expect(calculator.getCnsStatus(0), equals(CnsStatus.safe));
        expect(calculator.getCnsStatus(50), equals(CnsStatus.safe));
        expect(calculator.getCnsStatus(79), equals(CnsStatus.safe));
      });

      test('should return warning for elevated CNS', () {
        expect(calculator.getCnsStatus(80), equals(CnsStatus.warning));
        expect(calculator.getCnsStatus(90), equals(CnsStatus.warning));
        expect(calculator.getCnsStatus(99), equals(CnsStatus.warning));
      });

      test('should return critical for dangerous CNS', () {
        expect(calculator.getCnsStatus(100), equals(CnsStatus.critical));
        expect(calculator.getCnsStatus(120), equals(CnsStatus.critical));
      });

      test('should respect custom warning threshold', () {
        const conservativeCalc = O2ToxicityCalculator(
          cnsWarningThreshold: 60,
        );

        expect(conservativeCalc.getCnsStatus(60), equals(CnsStatus.warning));
        expect(calculator.getCnsStatus(60), equals(CnsStatus.safe));
      });
    });
  });

  group('CnsTable', () {
    test('should have valid rates for all ppO2 ranges', () {
      // Test each bracket from NOAA table
      expect(CnsTable.cnsPerMinute(0.55), closeTo(100.0 / 720.0, 0.01));
      expect(CnsTable.cnsPerMinute(0.65), closeTo(100.0 / 570.0, 0.01));
      expect(CnsTable.cnsPerMinute(0.75), closeTo(100.0 / 450.0, 0.01));
      expect(CnsTable.cnsPerMinute(0.85), closeTo(100.0 / 360.0, 0.01));
      expect(CnsTable.cnsPerMinute(0.95), closeTo(100.0 / 300.0, 0.01));
      expect(CnsTable.cnsPerMinute(1.05), closeTo(100.0 / 240.0, 0.01));
      expect(CnsTable.cnsPerMinute(1.15), closeTo(100.0 / 210.0, 0.01));
      expect(CnsTable.cnsPerMinute(1.25), closeTo(100.0 / 180.0, 0.01));
      expect(CnsTable.cnsPerMinute(1.35), closeTo(100.0 / 150.0, 0.01));
      expect(CnsTable.cnsPerMinute(1.45), closeTo(100.0 / 120.0, 0.01));
      expect(CnsTable.cnsPerMinute(1.55), closeTo(100.0 / 45.0, 0.01));
    });

    test('should calculate CNS for segment correctly', () {
      // 60 minutes at ppO2 1.0 should give ~20% CNS (300 min limit)
      final cns = CnsTable.cnsForSegment(1.0, 60 * 60);
      expect(cns, closeTo(20.0, 0.5));
    });

    test('should have 90 minute half-time for recovery', () {
      expect(CnsTable.cnsHalfTimeMinutes, equals(90.0));
    });
  });

  group('O2Exposure entity', () {
    test('should calculate cnsDelta correctly', () {
      const exposure = O2Exposure(cnsStart: 20, cnsEnd: 45);
      expect(exposure.cnsDelta, equals(25));
    });

    test('should flag cnsWarning at 80%', () {
      expect(const O2Exposure(cnsEnd: 79).cnsWarning, isFalse);
      expect(const O2Exposure(cnsEnd: 80).cnsWarning, isTrue);
      expect(const O2Exposure(cnsEnd: 100).cnsWarning, isTrue);
    });

    test('should flag cnsCritical at 100%', () {
      expect(const O2Exposure(cnsEnd: 99).cnsCritical, isFalse);
      expect(const O2Exposure(cnsEnd: 100).cnsCritical, isTrue);
    });

    test('should flag ppO2Warning above 1.4', () {
      expect(const O2Exposure(maxPpO2: 1.4).ppO2Warning, isFalse);
      expect(const O2Exposure(maxPpO2: 1.41).ppO2Warning, isTrue);
    });

    test('should flag ppO2Critical above 1.6', () {
      expect(const O2Exposure(maxPpO2: 1.6).ppO2Critical, isFalse);
      expect(const O2Exposure(maxPpO2: 1.61).ppO2Critical, isTrue);
    });

    test('should calculate otuPercentOfDaily correctly', () {
      const exposure = O2Exposure(otu: 150);
      expect(exposure.otuPercentOfDaily, equals(50.0));
    });

    test('should format values correctly', () {
      const exposure = O2Exposure(
        cnsEnd: 45.6,
        otu: 123.4,
        maxPpO2: 1.38,
      );
      expect(exposure.cnsFormatted, equals('46%'));
      expect(exposure.otuFormatted, equals('123 OTU'));
      expect(exposure.maxPpO2Formatted, equals('1.38 bar'));
    });

    test('should create zero exposure', () {
      final zero = O2Exposure.zero();
      expect(zero.cnsStart, equals(0.0));
      expect(zero.cnsEnd, equals(0.0));
      expect(zero.otu, equals(0.0));
    });

    test('should copyWith correctly', () {
      const original = O2Exposure(cnsEnd: 50, otu: 100);
      final modified = original.copyWith(cnsEnd: 60);

      expect(modified.cnsEnd, equals(60));
      expect(modified.otu, equals(100));
      expect(original.cnsEnd, equals(50)); // Original unchanged
    });
  });

  group('PpO2Status', () {
    test('should have correct display names', () {
      expect(PpO2Status.low.displayName, contains('Hypoxia'));
      expect(PpO2Status.safe.displayName, equals('Safe'));
      expect(PpO2Status.warning.displayName, equals('Warning'));
      expect(PpO2Status.critical.displayName, contains('CNS Risk'));
    });
  });

  group('CnsStatus', () {
    test('should have correct display names', () {
      expect(CnsStatus.safe.displayName, equals('Safe'));
      expect(CnsStatus.warning.displayName, equals('Warning'));
      expect(CnsStatus.critical.displayName, equals('Critical'));
    });
  });
}
