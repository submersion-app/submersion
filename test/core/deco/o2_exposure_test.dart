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
}
