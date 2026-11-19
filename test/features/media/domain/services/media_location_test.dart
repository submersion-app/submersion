import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_location.dart';

/// Where a photo or video was taken, for limiting names to the species
/// recorded there: its own position, else its dive's site, else where the
/// dive's computer logged its entry (issues #4668, #4727).
void main() {
  MediaItem item({double? lat, double? lon}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    latitude: lat,
    longitude: lon,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  const site = GeoPoint(20.5, -87.0);
  const entry = GeoPoint(20.6, -87.1);

  test('its own position first', () {
    expect(
      mediaLocation(
        item(lat: 12, lon: -68),
        siteLocation: site,
        entryLocation: entry,
      ),
      const GeoPoint(12, -68),
    );
  });

  test('else the site', () {
    expect(
      mediaLocation(item(), siteLocation: site, entryLocation: entry),
      site,
    );
  });

  test('else the entry', () {
    expect(mediaLocation(item(), entryLocation: entry), entry);
  });

  test('else none', () {
    expect(mediaLocation(item()), isNull);
  });
}
