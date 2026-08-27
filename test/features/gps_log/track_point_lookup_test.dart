import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_point_info_card.dart';

GpsTrackPoint p(int t, double lat) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: 0.0, accuracy: 5.0);

void main() {
  // Full track at 1 Hz; the simplified run keeps only the endpoints.
  final full = [
    p(0, 0.0000),
    p(1, 0.0001),
    p(2, 0.0002),
    p(3, 0.0003),
    p(4, 0.0004),
  ];
  final run = TrackRun(points: [full.first, full.last], bucket: 0);

  test('returns a fix that survived decimation only in the full list', () {
    // Tap nearest to the t=2 fix, which is NOT in the simplified run.
    final hit = nearestPointInRun(
      fullPoints: full,
      run: run,
      tapped: const LatLng(0.0002, 0.0),
    );
    expect(hit, isNotNull);
    expect(hit!.point.timestamp, 2);
  });

  test('reports the speed of the leg arriving at that fix', () {
    final hit = nearestPointInRun(
      fullPoints: full,
      run: run,
      tapped: const LatLng(0.0002, 0.0),
    );
    // 0.0001 deg latitude = 11.12 m, over 1 s.
    expect(hit!.speedMps, closeTo(11.12, 0.05));
  });

  test('clamps the search to the run span, not the whole track', () {
    final shortRun = TrackRun(points: [full[0], full[1]], bucket: 0);
    final hit = nearestPointInRun(
      fullPoints: full,
      run: shortRun,
      tapped: const LatLng(0.0004, 0.0),
    );
    // Tapped near t=4, but the run only spans t=0..1, so it clamps to t=1.
    expect(hit!.point.timestamp, 1);
  });

  test('returns zero speed for the very first fix', () {
    final hit = nearestPointInRun(
      fullPoints: full,
      run: run,
      tapped: const LatLng(0.0, 0.0),
    );
    expect(hit!.point.timestamp, 0);
    expect(hit.speedMps, 0.0);
  });

  test('returns null for an empty run', () {
    final hit = nearestPointInRun(
      fullPoints: full,
      run: const TrackRun(points: [], bucket: 0),
      tapped: const LatLng(0.0, 0.0),
    );
    expect(hit, isNull);
  });

  test('returns null for an empty full-point list', () {
    final hit = nearestPointInRun(
      fullPoints: const [],
      run: run,
      tapped: const LatLng(0.0, 0.0),
    );
    expect(hit, isNull);
  });
}
