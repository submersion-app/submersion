/// Real-sample regression for the video GPS readers.
///
/// GPMF is a binary telemetry format and the QuickTime meta layout differs
/// between writers, so synthetic fixtures alone do not prove the readers.
/// Point these dart-defines at real clips (kept OUTSIDE the repo, e.g. in the
/// "submersion data" samples folder) and pass their expected positions:
///
///   flutter test \
///     --dart-define=GOPRO_MP4_SAMPLE=/path/GX010001.MP4 \
///     --dart-define=GOPRO_EXPECTED_LAT=20.5123 \
///     --dart-define=GOPRO_EXPECTED_LON=-87.2512 \
///     --dart-define=IPHONE_MOV_SAMPLE=/path/IMG_0001.MOV \
///     --dart-define=IPHONE_EXPECTED_LAT=20.5123 \
///     --dart-define=IPHONE_EXPECTED_LON=-87.2512 \
///     --run-skipped --tags=real-data \
///     test/features/media/data/services/video_gps_real_sample_test.dart
///
/// Without the dart-defines (or when a file is missing) every test skips so CI
/// and fresh clones stay green.
@Tags(['real-data'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/gpmf_gps_reader.dart';
import 'package:submersion/features/media/data/services/local_gps_reader.dart';
import 'package:submersion/features/media/data/services/quicktime_location_reader.dart';

const _goPro = String.fromEnvironment('GOPRO_MP4_SAMPLE');
const _goProLat = String.fromEnvironment('GOPRO_EXPECTED_LAT');
const _goProLon = String.fromEnvironment('GOPRO_EXPECTED_LON');
const _iphone = String.fromEnvironment('IPHONE_MOV_SAMPLE');
const _iphoneLat = String.fromEnvironment('IPHONE_EXPECTED_LAT');
const _iphoneLon = String.fromEnvironment('IPHONE_EXPECTED_LON');

bool _skipUnless(String path, String lat, String lon, String name) {
  if (path.isNotEmpty &&
      File(path).existsSync() &&
      lat.isNotEmpty &&
      lon.isNotEmpty) {
    return false;
  }
  markTestSkipped(
    '$name sample not available. Set the *_SAMPLE and *_EXPECTED_* '
    'dart-defines and pass --run-skipped --tags=real-data to run.',
  );
  return true;
}

void main() {
  group('GoPro GPMF real sample', () {
    test('readGpmfGps and readLocalGps agree with the expected position', () {
      if (_skipUnless(_goPro, _goProLat, _goProLon, 'GoPro')) return;
      final file = File(_goPro);
      final direct = readGpmfGps(file);
      final viaDispatch = readLocalGps(file, 'video/mp4');
      expect(direct, isNotNull);
      expect(direct!.latitude, closeTo(double.parse(_goProLat), 0.001));
      expect(direct.longitude, closeTo(double.parse(_goProLon), 0.001));
      expect(viaDispatch, direct);
    });
  });

  group('iPhone MOV real sample', () {
    test(
      'readQuickTimeLocation and readLocalGps agree with the expected position',
      () {
        if (_skipUnless(_iphone, _iphoneLat, _iphoneLon, 'iPhone')) return;
        final file = File(_iphone);
        final direct = readQuickTimeLocation(file);
        final viaDispatch = readLocalGps(file, 'video/quicktime');
        expect(direct, isNotNull);
        expect(direct!.latitude, closeTo(double.parse(_iphoneLat), 0.001));
        expect(direct.longitude, closeTo(double.parse(_iphoneLon), 0.001));
        expect(viaDispatch, direct);
      },
    );
  });
}
