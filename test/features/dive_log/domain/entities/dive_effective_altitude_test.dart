import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Issue #5040: a dive with no altitude of its own reads its site's, and its
/// environment (the deco replay, every pressure from depth) follows.
void main() {
  DiveSite site({double? altitude}) =>
      DiveSite(id: 'site', name: 'Site', altitude: altitude);

  Dive dive({double? altitude, DiveSite? site}) => Dive(
    id: 'dive',
    dateTime: DateTime(2026),
    altitude: altitude,
    site: site,
  );

  test('falls back to the site when the dive has no altitude', () {
    expect(dive(site: site(altitude: 450)).effectiveAltitude, 450);
  });

  test("the dive's own value wins over the site's", () {
    expect(
      dive(altitude: 1200, site: site(altitude: 450)).effectiveAltitude,
      1200,
    );
  });

  test('is null when neither the dive nor its site knows', () {
    expect(dive(site: site()).effectiveAltitude, isNull);
    expect(dive().effectiveAltitude, isNull);
  });

  test("the environment is the site's altitude when the dive has none", () {
    final environment = dive(site: site(altitude: 2000)).environment;
    expect(
      environment.surfacePressureBar,
      closeTo(AltitudeCalculator.calculateBarometricPressure(2000), 1e-9),
    );
  });
}
