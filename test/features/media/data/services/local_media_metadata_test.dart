import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/capture_time_reader.dart';
import 'package:submersion/features/media/data/services/local_gps_reader.dart';
import 'package:submersion/features/media/data/services/local_media_metadata.dart';

import '../../../../helpers/media_container_fixtures.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('local_media_metadata_');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File jpeg(String name, void Function(img.ExifData exif) configure) =>
      File('${tempDir.path}/$name')..writeAsBytesSync(jpegWithExif(configure));

  /// The reader must agree with the single-purpose readers it replaces --
  /// they stay the public entry points for callers that want only one half.
  void expectAgreesWithSingleReaders(File file, String mime) {
    final meta = readLocalMediaMetadata(file, mime);
    expect(meta.capturedUtc, readLocalCaptureTime(file, mime));
    expect(meta.fix, readLocalGps(file, mime));
  }

  group('stills', () {
    test('one EXIF parse yields both the capture time and the fix', () {
      final f = jpeg('both.jpg', (e) {
        e.exifIfd['DateTimeOriginal'] = '2026:05:06 17:35:39';
        e.gpsIfd.gpsLatitude = 20.5;
        e.gpsIfd.gpsLatitudeRef = 'N';
        e.gpsIfd.gpsLongitude = 87.25;
        e.gpsIfd.gpsLongitudeRef = 'W';
      });

      final meta = readLocalMediaMetadata(f, 'image/jpeg');
      expect(meta.capturedUtc, DateTime.utc(2026, 5, 6, 17, 35, 39));
      expect(meta.fix?.latitude, closeTo(20.5, 1e-6));
      expect(meta.fix?.longitude, closeTo(-87.25, 1e-6));
      expectAgreesWithSingleReaders(f, 'image/jpeg');
    });

    test('a date without a fix, and a fix without a date', () {
      final dated = jpeg(
        'dated.jpg',
        (e) => e.exifIfd['DateTimeOriginal'] = '2026:01:02 03:04:05',
      );
      final located = jpeg('located.jpg', (e) {
        e.gpsIfd.gpsLatitude = 12.5;
        e.gpsIfd.gpsLatitudeRef = 'S';
        e.gpsIfd.gpsLongitude = 45.25;
        e.gpsIfd.gpsLongitudeRef = 'E';
      });

      final datedMeta = readLocalMediaMetadata(dated, 'image/jpeg');
      expect(datedMeta.capturedUtc, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(datedMeta.fix, isNull);

      final locatedMeta = readLocalMediaMetadata(located, 'image/jpeg');
      expect(locatedMeta.capturedUtc, isNull);
      expect(locatedMeta.fix?.latitude, closeTo(-12.5, 1e-6));

      expectAgreesWithSingleReaders(dated, 'image/jpeg');
      expectAgreesWithSingleReaders(located, 'image/jpeg');
    });

    test('a still with no EXIF, an unsupported mime, and a missing file', () {
      final bare = File('${tempDir.path}/bare.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));
      final gone = File('${tempDir.path}/gone.jpg');

      for (final (file, mime) in [
        (bare, 'image/png'),
        (bare, 'image/jpeg'),
        (gone, 'image/jpeg'),
      ]) {
        final meta = readLocalMediaMetadata(file, mime);
        expect(meta.capturedUtc, isNull, reason: mime);
        expect(meta.fix, isNull, reason: mime);
      }
    });
  });

  group('video', () {
    List<int> mvhd(int creationTime) => fullBox('mvhd', [
      ...u32(creationTime),
      ...u32(creationTime),
      ...u32(1000),
      ...u32(5000),
      ...List.filled(80, 0),
    ]);

    List<int> xyz(String text) =>
        box('©xyz', [...u16(text.length), ...u16(0), ...text.codeUnits]);

    test('one pass yields both the mvhd time and the location atom', () {
      final shot = DateTime.utc(2026, 5, 6, 17, 35, 39);
      // mvhd counts seconds from the 1904 QuickTime epoch, not 1970.
      final creation = shot.millisecondsSinceEpoch ~/ 1000 + 2082844800;
      final f = File('${tempDir.path}/clip.mov')
        ..writeAsBytesSync([
          ...box('ftyp', 'qt  '.codeUnits),
          ...box('moov', [
            ...mvhd(creation),
            ...box('udta', xyz('+37.3323-122.0312/')),
          ]),
        ]);

      final meta = readLocalMediaMetadata(f, 'video/quicktime');
      expect(meta.capturedUtc, shot);
      expect(meta.fix?.latitude, closeTo(37.3323, 1e-6));
      expect(meta.fix?.longitude, closeTo(-122.0312, 1e-6));
      expectAgreesWithSingleReaders(f, 'video/quicktime');
    });

    test('a clip with neither yields nothing', () {
      final f = File('${tempDir.path}/bare.mp4')
        ..writeAsBytesSync([
          ...box('ftyp', 'isom'.codeUnits),
          ...box('moov', box('mvhd', [])),
        ]);

      final meta = readLocalMediaMetadata(f, 'video/mp4');
      expect(meta.capturedUtc, isNull);
      expect(meta.fix, isNull);
    });
  });
}
