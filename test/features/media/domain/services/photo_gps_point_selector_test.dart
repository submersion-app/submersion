import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/services/photo_gps_point_selector.dart';

PhotoGpsPoint _p(String id, DateTime at) =>
    (mediaId: id, location: const GeoPoint(1, 1), takenAt: at);

void main() {
  final entry = DateTime.utc(2025, 12, 27, 11, 26);

  test('picks the sample nearest the entry time, before or after', () {
    final best = selectBestPhotoGps([
      _p('hotel', DateTime.utc(2025, 12, 27, 7, 0)),
      _p('boat', DateTime.utc(2025, 12, 27, 11, 20)),
      _p('after', DateTime.utc(2025, 12, 27, 12, 30)),
    ], entry);
    expect(best?.mediaId, 'boat');
  });

  test('ties go to the earlier sample', () {
    final best = selectBestPhotoGps([
      _p('later', DateTime.utc(2025, 12, 27, 11, 36)),
      _p('earlier', DateTime.utc(2025, 12, 27, 11, 16)),
    ], entry);
    expect(best?.mediaId, 'earlier');
  });

  test('empty input yields null', () {
    expect(selectBestPhotoGps(const [], entry), isNull);
  });
}
