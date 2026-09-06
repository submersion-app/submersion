import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';

void main() {
  group('O2Exposure cumulative OTU', () {
    test('otuDaily should equal otuStart plus otu', () {
      const exposure = O2Exposure(otu: 45.0, otuStart: 120.0);
      expect(exposure.otuDaily, equals(165.0));
    });

    test('otuDaily defaults to otu when otuStart is zero', () {
      const exposure = O2Exposure(otu: 45.0);
      expect(exposure.otuDaily, equals(45.0));
    });

    test('otuDailyPercentOfLimit should use daily total', () {
      const exposure = O2Exposure(otu: 45.0, otuStart: 255.0);
      // otuDaily = 300, dailyOtuLimit = 300, so 100%
      expect(exposure.otuDailyPercentOfLimit, equals(100.0));
    });

    test('copyWith should preserve otuStart', () {
      const original = O2Exposure(otu: 45.0, otuStart: 120.0);
      final copy = original.copyWith(otu: 50.0);
      expect(copy.otuStart, equals(120.0));
      expect(copy.otu, equals(50.0));
      expect(copy.otuDaily, equals(170.0));
    });

    test('otuStart should be included in props for equality', () {
      const a = O2Exposure(otu: 45.0, otuStart: 120.0);
      const b = O2Exposure(otu: 45.0, otuStart: 0.0);
      expect(a, isNot(equals(b)));
    });
  });

  group('O2Exposure ppO2 thresholds', () {
    test('defaults keep the 1.4 / 1.6 bar limits', () {
      const e = O2Exposure(maxPpO2: 1.5);
      expect(e.warningThreshold, 1.4);
      expect(e.criticalThreshold, 1.6);
      expect(e.ppO2Warning, isTrue); // 1.5 > 1.4
      expect(e.ppO2Critical, isFalse); // 1.5 < 1.6
    });

    test('a raised working limit clears the warning at the same ppO2', () {
      const raised = O2Exposure(
        maxPpO2: 1.5,
        warningThreshold: 1.6,
        criticalThreshold: 1.6,
      );
      expect(raised.ppO2Warning, isFalse);
      expect(raised.ppO2Critical, isFalse);
    });

    test('a lowered limit flags a ppO2 the default would allow', () {
      const conservative = O2Exposure(
        maxPpO2: 1.35,
        warningThreshold: 1.2,
        criticalThreshold: 1.4,
      );
      expect(conservative.ppO2Warning, isTrue); // 1.35 > 1.2
      expect(conservative.ppO2Critical, isFalse); // 1.35 < 1.4
    });

    test('thresholds are part of equality and copyWith', () {
      const a = O2Exposure(maxPpO2: 1.5);
      const b = O2Exposure(maxPpO2: 1.5, warningThreshold: 1.5);
      expect(a, isNot(equals(b)));
      expect(a.copyWith(criticalThreshold: 1.5).criticalThreshold, 1.5);
    });
  });
}
