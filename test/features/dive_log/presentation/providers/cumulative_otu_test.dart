import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';

void main() {
  group('Cumulative OTU computation', () {
    test('otuDaily should accumulate across dives', () {
      // Dive 1: 45 OTU
      const dive1 = O2Exposure(otu: 45.0, otuStart: 0.0);
      expect(dive1.otuDaily, equals(45.0));

      // Dive 2: 38 OTU, startOtu = 45 (from dive 1)
      const dive2 = O2Exposure(otu: 38.0, otuStart: 45.0);
      expect(dive2.otuDaily, equals(83.0));

      // Dive 3: 52 OTU, startOtu = 83 (from dives 1+2)
      const dive3 = O2Exposure(otu: 52.0, otuStart: 83.0);
      expect(dive3.otuDaily, equals(135.0));
    });

    test('otuDailyPercentOfLimit should show correct percentage', () {
      const exposure = O2Exposure(otu: 50.0, otuStart: 250.0);
      // otuDaily = 300, limit = 300, so 100%
      expect(exposure.otuDailyPercentOfLimit, equals(100.0));
    });

    test('weekly OTU limit constant should be 850', () {
      expect(O2Exposure.weeklyOtuLimit, equals(850.0));
    });
  });
}
