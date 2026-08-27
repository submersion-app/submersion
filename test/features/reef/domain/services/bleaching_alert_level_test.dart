import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';

void main() {
  group('BleachingAlertLevel.derive', () {
    test('returns null when either input is null', () {
      expect(BleachingAlertLevel.derive(dhw: null, hotspot: 1.2), isNull);
      expect(BleachingAlertLevel.derive(dhw: 4.0, hotspot: null), isNull);
    });

    test('no stress when hotspot is zero or below', () {
      expect(
        BleachingAlertLevel.derive(dhw: 0, hotspot: 0),
        BleachingAlertLevel.noStress,
      );
      expect(
        BleachingAlertLevel.derive(dhw: 0, hotspot: -0.51),
        BleachingAlertLevel.noStress,
      );
    });

    test('watch when hotspot is between zero and one', () {
      expect(
        BleachingAlertLevel.derive(dhw: 0.2, hotspot: 0.96),
        BleachingAlertLevel.watch,
      );
    });

    test('warning when hotspot at least one and dhw below four', () {
      expect(
        BleachingAlertLevel.derive(dhw: 3.68, hotspot: 1.0),
        BleachingAlertLevel.warning,
      );
    });

    test('alert levels one through five by dhw band', () {
      expect(
        BleachingAlertLevel.derive(dhw: 4.0, hotspot: 1.2),
        BleachingAlertLevel.alertLevel1,
      );
      expect(
        BleachingAlertLevel.derive(dhw: 8.0, hotspot: 1.2),
        BleachingAlertLevel.alertLevel2,
      );
      expect(
        BleachingAlertLevel.derive(dhw: 12.0, hotspot: 1.2),
        BleachingAlertLevel.alertLevel3,
      );
      expect(
        BleachingAlertLevel.derive(dhw: 16.0, hotspot: 1.2),
        BleachingAlertLevel.alertLevel4,
      );
      expect(
        BleachingAlertLevel.derive(dhw: 20.0, hotspot: 1.2),
        BleachingAlertLevel.alertLevel5,
      );
    });

    // Verified against the real NOAA API during research. The stored CRW_BAA
    // was 4 on both dates; the derived level must exceed it.
    test(
      'Florida Keys 2023-09-19 derives Alert Level 4, above the capped BAA',
      () {
        expect(
          BleachingAlertLevel.derive(dhw: 17.17, hotspot: 1.47),
          BleachingAlertLevel.alertLevel4,
        );
      },
    );

    // The trap: HotSpot dipped below 1 while DHW stayed catastrophic. The
    // level is legitimately "watch", which is exactly why the UI must show
    // DHW alongside it.
    test('Florida Keys 2023-09-01 derives watch despite catastrophic dhw', () {
      final level = BleachingAlertLevel.derive(dhw: 15.64, hotspot: 0.91);
      expect(level, BleachingAlertLevel.watch);
      expect(level!.code, 1);
    });

    test('codes match the published NOAA scale', () {
      expect(BleachingAlertLevel.noStress.code, 0);
      expect(BleachingAlertLevel.watch.code, 1);
      expect(BleachingAlertLevel.warning.code, 2);
      expect(BleachingAlertLevel.alertLevel5.code, 7);
    });
  });
}
