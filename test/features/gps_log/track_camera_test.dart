import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';

GpsTrackPoint p(double lat, double lon) =>
    GpsTrackPoint(timestamp: 0, latitude: lat, longitude: lon);

/// Taveuni sits on the 180th meridian; Fiji boat days routinely cross it.
final _fiji = [p(-16.8, 179.9), p(-16.85, 179.99), p(-16.9, -179.9)];
final _cozumel = [p(20.5, -87.25), p(20.51, -87.26), p(20.52, -87.27)];

void main() {
  group('crossesAntimeridian', () {
    test('is true for an unwrapped span', () {
      expect(crossesAntimeridian(trackBounds(_fiji)!), isTrue);
    });

    test('is false for an ordinary track', () {
      expect(crossesAntimeridian(trackBounds(_cozumel)!), isFalse);
    });
  });

  group('normalizeLongitude', () {
    test('wraps an unwrapped longitude back into range', () {
      expect(normalizeLongitude(180.1), closeTo(-179.9, 1e-9));
    });

    test('leaves a legal longitude alone', () {
      expect(normalizeLongitude(-87.25), closeTo(-87.25, 1e-9));
      expect(normalizeLongitude(179.9), closeTo(179.9, 1e-9));
    });
  });

  group('TrackCamera', () {
    test('uses a bounds fit for an ordinary track', () {
      final camera = TrackCamera.forPoints(_cozumel)!;
      expect(camera.fit, isNotNull);
      expect(camera.center, isNull);
    });

    test('an antimeridian track does not build a LatLngBounds', () {
      // Regression: trackBounds correctly reports maxLon 180.1, and
      // LatLngBounds asserts east <= 180 - a red screen on every Fiji track.
      final camera = TrackCamera.forPoints(_fiji)!;
      expect(camera.fit, isNull);
      expect(camera.center, isNotNull);
      expect(camera.zoom, isNotNull);
    });

    test('the antimeridian centre is a legal longitude', () {
      final camera = TrackCamera.forPoints(_fiji)!;
      expect(camera.center!.longitude, greaterThanOrEqualTo(-180.0));
      expect(camera.center!.longitude, lessThanOrEqualTo(180.0));
      // Centre of 179.9..180.1 is 180.0, which wraps to -180.0.
      expect(camera.center!.longitude.abs(), closeTo(180.0, 0.05));
    });

    test('constructing LatLngBounds from the raw fit never throws', () {
      // The bounds path is only taken when it is legal, so this must hold
      // for both shapes.
      for (final points in [_cozumel, _fiji]) {
        expect(() => TrackCamera.forPoints(points), returnsNormally);
      }
    });

    test('honours the maxZoom cap on the antimeridian path too', () {
      final camera = TrackCamera.forPoints(_fiji, maxZoom: 12.0)!;
      expect(camera.zoom, lessThanOrEqualTo(12.0));
    });

    test('returns null when there is nothing to frame', () {
      expect(TrackCamera.forPoints(const []), isNull);
    });
  });

  group('longitudeInBoundsFrame', () {
    test('shifts a western longitude into the unwrapped frame', () {
      final bounds = trackBounds(_fiji)!;
      expect(longitudeInBoundsFrame(-179.9, bounds), closeTo(180.1, 1e-9));
      expect(longitudeInBoundsFrame(179.9, bounds), closeTo(179.9, 1e-9));
    });

    test('leaves longitudes alone for an ordinary track', () {
      final bounds = trackBounds(_cozumel)!;
      expect(longitudeInBoundsFrame(-87.25, bounds), closeTo(-87.25, 1e-9));
    });
  });

  test('a LatLngBounds built from the fiji bounds WOULD assert', () {
    // Pins the reason TrackCamera exists. If flutter_map ever accepts an
    // unwrapped east, this test fails and the workaround can be removed.
    final bounds = trackBounds(_fiji)!;
    expect(
      () => LatLngBounds(
        LatLng(bounds.minLat, bounds.minLon),
        LatLng(bounds.maxLat, bounds.maxLon),
      ),
      throwsA(anything),
    );
  });
}
