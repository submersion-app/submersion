import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/router/track_locations.dart';

void main() {
  test('every tracks page lives under /tracks', () {
    expect(kTracksLocation, '/tracks');
    expect(kTracksMapLocation, '/tracks/map');
    expect(kUnderwaterTracksLocation, '/tracks?kind=underwater');
    expect(gpsTrackLocation('a'), '/tracks/gps/a');
    expect(underwaterTrackLocation('b'), '/tracks/underwater/b');
    expect(underwaterTrackAlignLocation('b'), '/tracks/underwater/b/align');
    expect(underwaterTrackSeascapeLocation('b'), '/tracks/underwater/b/3d');
  });
}
