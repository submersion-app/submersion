import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/local_gps_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

void main() {
  group('isPlausibleFix', () {
    test('accepts in-range coordinates', () {
      expect(isPlausibleFix(12.34, -98.76), isTrue);
      expect(isPlausibleFix(-90, 180), isTrue);
    });
    test('rejects (0,0), NaN, and out-of-range values', () {
      expect(isPlausibleFix(0, 0), isFalse);
      expect(isPlausibleFix(double.nan, 10), isFalse);
      expect(isPlausibleFix(91, 10), isFalse);
      expect(isPlausibleFix(10, -181), isFalse);
      expect(isPlausibleFix(double.infinity, 0), isFalse);
    });
  });

  group('gpsFromExif', () {
    img.ExifData exifWith({
      double? lat,
      String? latRef,
      double? lon,
      String? lonRef,
    }) {
      final e = img.ExifData();
      if (lat != null) e.gpsIfd.gpsLatitude = lat;
      if (latRef != null) e.gpsIfd.gpsLatitudeRef = latRef;
      if (lon != null) e.gpsIfd.gpsLongitude = lon;
      if (lonRef != null) e.gpsIfd.gpsLongitudeRef = lonRef;
      return e;
    }

    test('north-east stays positive', () {
      final fix = gpsFromExif(
        exifWith(lat: 12.3456, latRef: 'N', lon: 98.7654, lonRef: 'E'),
      );
      expect(fix?.latitude, closeTo(12.3456, 1e-6));
      expect(fix?.longitude, closeTo(98.7654, 1e-6));
    });

    test('south and west negate', () {
      final fix = gpsFromExif(
        exifWith(lat: 33.8688, latRef: 'S', lon: 151.2093, lonRef: 'W'),
      );
      expect(fix?.latitude, closeTo(-33.8688, 1e-6));
      expect(fix?.longitude, closeTo(-151.2093, 1e-6));
    });

    test('a missing ref is treated as N / E', () {
      final fix = gpsFromExif(exifWith(lat: 1.5, lon: 2.5));
      expect(fix?.latitude, closeTo(1.5, 1e-6));
      expect(fix?.longitude, closeTo(2.5, 1e-6));
    });

    test('a missing axis or an empty GPS IFD yields null', () {
      expect(gpsFromExif(exifWith(lat: 1.5, latRef: 'N')), isNull);
      expect(gpsFromExif(img.ExifData()), isNull);
    });

    test('(0,0) and out-of-range values yield null', () {
      expect(gpsFromExif(exifWith(lat: 0, lon: 0)), isNull);
      expect(gpsFromExif(exifWith(lat: 95, lon: 10)), isNull);
    });

    test(
      'reads degree/minute/second rationals as the EXIF spec stores them',
      () {
        // 12 deg 20 min 44.16 sec = 12.3456; the reader must sum
        // d + m/60 + s/3600 and apply the hemisphere refs.
        img.IfdValueRational triple(int d, int m, int sNum, int sDen) =>
            img.IfdValueRational.data(
              img.InputBuffer(
                Uint8List.fromList([
                  ...u32(d),
                  ...u32(1),
                  ...u32(m),
                  ...u32(1),
                  ...u32(sNum),
                  ...u32(sDen),
                ]),
                bigEndian: true,
              ),
              3,
            );
        final e = img.ExifData();
        e.gpsIfd[0x0002] = triple(12, 20, 4416, 100);
        e.gpsIfd[0x0001] = img.IfdValueAscii('N');
        e.gpsIfd[0x0004] = triple(98, 45, 5544, 100);
        e.gpsIfd[0x0003] = img.IfdValueAscii('W');
        final fix = gpsFromExif(e);
        expect(fix?.latitude, closeTo(12.3456, 1e-6));
        expect(fix?.longitude, closeTo(-98.7654, 1e-6));
      },
    );
  });

  group('readLocalGps for images', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_gps_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('JPEG with GPS', () {
      final f = File('${tempDir.path}/a.jpg')
        ..writeAsBytesSync(
          jpegWithExif((e) {
            e.gpsIfd.gpsLatitude = 20.5;
            e.gpsIfd.gpsLatitudeRef = 'N';
            e.gpsIfd.gpsLongitude = 87.25;
            e.gpsIfd.gpsLongitudeRef = 'W';
          }),
        );
      final fix = readLocalGps(f, 'image/jpeg');
      expect(fix?.latitude, closeTo(20.5, 1e-6));
      expect(fix?.longitude, closeTo(-87.25, 1e-6));
    });

    test('JPEG without GPS, PNG, and a missing file yield null', () {
      final noGps = File('${tempDir.path}/b.jpg')
        ..writeAsBytesSync(
          jpegWithExif(
            (e) => e.exifIfd['DateTimeOriginal'] = '2025:01:01 00:00:00',
          ),
        );
      expect(readLocalGps(noGps, 'image/jpeg'), isNull);
      expect(readLocalGps(noGps, 'image/png'), isNull);
      expect(
        readLocalGps(File('${tempDir.path}/none.jpg'), 'image/jpeg'),
        isNull,
      );
    });
  });

  group('readLocalGps for video', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_gps_video_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    List<int> xyz(String text) =>
        box('©xyz', [...u16(text.length), ...u16(0), ...text.codeUnits]);

    test('QuickTime location wins for a MOV', () {
      final f = File('${tempDir.path}/a.mov')
        ..writeAsBytesSync([
          ...box('ftyp', 'qt  '.codeUnits),
          ...box('moov', box('udta', xyz('+37.3323-122.0312/'))),
        ]);
      expect(
        readLocalGps(f, 'video/quicktime')?.latitude,
        closeTo(37.3323, 1e-6),
      );
    });

    test('a video with neither location atom nor telemetry yields null', () {
      final f = File('${tempDir.path}/b.mp4')
        ..writeAsBytesSync([
          ...box('ftyp', 'isom'.codeUnits),
          ...box('moov', box('mvhd', [])),
        ]);
      expect(readLocalGps(f, 'video/mp4'), isNull);
    });
  });
}
