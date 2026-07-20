import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/services/altitude_flag.dart';

void main() {
  test('flags when site is at altitude and dive has none', () {
    expect(
      needsAltitudeAdjustmentFlag(diveAltitude: null, siteAltitude: 2000),
      isTrue,
    );
    expect(
      needsAltitudeAdjustmentFlag(diveAltitude: 0, siteAltitude: 350),
      isTrue,
    );
  });

  test('does not flag adjusted dives or low sites', () {
    expect(
      needsAltitudeAdjustmentFlag(diveAltitude: 2000, siteAltitude: 2000),
      isFalse,
    );
    expect(
      needsAltitudeAdjustmentFlag(diveAltitude: null, siteAltitude: 50),
      isFalse,
    );
    expect(
      needsAltitudeAdjustmentFlag(diveAltitude: null, siteAltitude: null),
      isFalse,
    );
  });
}
