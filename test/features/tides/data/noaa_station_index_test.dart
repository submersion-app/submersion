import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';

void main() {
  final index = NoaaStationIndex.fromJsonString(
    '[["8443970","Boston",42.3539,-71.0503],'
    '["9414290","San Francisco",37.8063,-122.4659],'
    '["9413450","Monterey",36.6089,-121.8914]]',
  );

  test('nearest returns the closest station within range', () {
    // Point Lobos, ~10 km south of the Monterey station.
    final hit = index.nearest(36.5215, -121.9527);
    expect(hit, isNotNull);
    expect(hit!.id, '9413450');
    expect(hit.name, 'Monterey');
    expect(hit.distanceKm, closeTo(10.2, 1.5));
  });

  test('nearest returns null when nothing is within maxKm', () {
    // Mid-Atlantic: no station within 25 km.
    expect(index.nearest(30.0, -40.0), isNull);
  });

  test('maxKm is respected', () {
    expect(index.nearest(36.5215, -121.9527, maxKm: 5.0), isNull);
  });

  test('bundled asset parses and covers known stations', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loaded = await NoaaStationIndex.load();
    final sf = loaded.nearest(37.8063, -122.4659, maxKm: 1.0);
    expect(sf, isNotNull);
    expect(sf!.id, '9414290');
  });
}
