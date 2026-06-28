import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/built_in_site_dedup.dart';

ExternalDiveSite ext(String id, double lat, double lng) => ExternalDiveSite(
  externalId: id,
  name: id,
  latitude: lat,
  longitude: lng,
  source: 'test',
);

DiveSite usr(String id, double lat, double lng) =>
    DiveSite(id: id, name: id, location: GeoPoint(lat, lng));

void main() {
  test('suppresses a built-in coincident with a user site', () {
    final result = visibleBuiltInSites(
      [ext('a', 10.0, 20.0)],
      [usr('u', 10.0, 20.0)],
    );
    expect(result, isEmpty);
  });

  test('keeps a built-in far from any user site', () {
    final result = visibleBuiltInSites(
      [ext('a', 10.0, 20.0)],
      [usr('u', 40.0, 80.0)],
    );
    expect(result.map((s) => s.externalId), ['a']);
  });

  test('keeps a built-in just outside the radius, suppresses just inside', () {
    // ~0.001 deg latitude is ~111 m (inside 150 m);
    // ~0.01 deg latitude is ~1.1 km (outside 150 m).
    final result = visibleBuiltInSites(
      [ext('inside', 10.001, 20.0), ext('outside', 10.01, 20.0)],
      [usr('u', 10.0, 20.0)],
    );
    expect(result.map((s) => s.externalId), ['outside']);
  });

  test('grid-bucketed result equals the naive cross-product', () {
    final builtIn = [
      for (var i = 0; i < 50; i++) ext('b$i', (i % 10) * 1.0, (i ~/ 10) * 1.0),
    ];
    final users = [
      usr('u0', 0.0, 0.0),
      usr('u1', 5.0, 2.0),
      usr('u2', 9.0, 4.0),
    ];
    final fast = visibleBuiltInSites(
      builtIn,
      users,
    ).map((s) => s.externalId).toSet();
    final naive = builtIn
        .where(
          (b) => !users.any(
            (u) =>
                distanceMetersForTest(
                  b.latitude!,
                  b.longitude!,
                  u.location!.latitude,
                  u.location!.longitude,
                ) <=
                150,
          ),
        )
        .map((s) => s.externalId)
        .toSet();
    expect(fast, naive);
  });
}

// Local mirror of the haversine for the equivalence test, so the test does
// not depend on the production grid path.
double distanceMetersForTest(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  return distanceMeters(GeoPoint(lat1, lng1), GeoPoint(lat2, lng2));
}
