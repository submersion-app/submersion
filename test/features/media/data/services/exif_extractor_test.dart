import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exif_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns metadata with mtime fallback when file has no EXIF', () async {
    final f = File('${tempDir.path}/no_exif.bin')
      ..writeAsBytesSync([0, 1, 2, 3]);
    final extractor = ExifExtractor();
    final meta = await extractor.extract(f);
    expect(meta, isNotNull);
    expect(meta!.takenAt, isNotNull); // file mtime fallback
    expect(
      meta.takenAt!.difference(DateTime.now()).abs(),
      lessThan(const Duration(minutes: 5)),
    );
    expect(meta.mimeType, isNotEmpty);
  });

  test('returns null on missing file', () async {
    final extractor = ExifExtractor();
    final meta = await extractor.extract(File('${tempDir.path}/missing'));
    expect(meta, isNull);
  });

  test('mimeType reflects file extension', () async {
    final extractor = ExifExtractor();
    final jpg = File('${tempDir.path}/x.jpg')..writeAsBytesSync([0]);
    final png = File('${tempDir.path}/x.png')..writeAsBytesSync([0]);
    final mp4 = File('${tempDir.path}/x.mp4')..writeAsBytesSync([0]);
    final mov = File('${tempDir.path}/x.mov')..writeAsBytesSync([0]);
    expect((await extractor.extract(jpg))!.mimeType, 'image/jpeg');
    expect((await extractor.extract(png))!.mimeType, 'image/png');
    expect((await extractor.extract(mp4))!.mimeType, 'video/mp4');
    expect((await extractor.extract(mov))!.mimeType, 'video/quicktime');
  });

  test('mimeType inference covers heic/heif/webp/gif/m4v + fallback', () async {
    final extractor = ExifExtractor();
    final heic = File('${tempDir.path}/x.heic')..writeAsBytesSync([0]);
    final heif = File('${tempDir.path}/x.heif')..writeAsBytesSync([0]);
    final webp = File('${tempDir.path}/x.webp')..writeAsBytesSync([0]);
    final gif = File('${tempDir.path}/x.gif')..writeAsBytesSync([0]);
    final m4v = File('${tempDir.path}/x.m4v')..writeAsBytesSync([0]);
    final unknown = File('${tempDir.path}/x.unknownext')..writeAsBytesSync([0]);
    expect((await extractor.extract(heic))!.mimeType, 'image/heic');
    expect((await extractor.extract(heif))!.mimeType, 'image/heif');
    expect((await extractor.extract(webp))!.mimeType, 'image/webp');
    expect((await extractor.extract(gif))!.mimeType, 'image/gif');
    expect((await extractor.extract(m4v))!.mimeType, 'video/x-m4v');
    expect(
      (await extractor.extract(unknown))!.mimeType,
      'application/octet-stream',
    );
  });

  group('with mocked native_exif channel', () {
    const channel = MethodChannel('native_exif');

    Map<String, Object?>? mockedAttributes;
    bool throwOnGetAttributes = false;

    setUp(() {
      mockedAttributes = null;
      throwOnGetAttributes = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'initPath':
                return 1; // Exif handle id
              case 'getAttributes':
                if (throwOnGetAttributes) {
                  throw PlatformException(code: 'parse-fail');
                }
                return mockedAttributes;
              case 'close':
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'parses DateTimeOriginal, GPS, and dimensions from EXIF attrs',
      () async {
        mockedAttributes = {
          'DateTimeOriginal': '2024:06:01 12:30:45',
          'GPSLatitude': 30.5,
          'GPSLatitudeRef': 'N',
          'GPSLongitude': 85.3,
          'GPSLongitudeRef': 'W',
          'PixelXDimension': 4032,
          'PixelYDimension': 3024,
        };
        final f = File('${tempDir.path}/photo.jpg')
          ..writeAsBytesSync([0, 1, 2]);
        final extractor = ExifExtractor();
        final meta = await extractor.extract(f);

        expect(meta, isNotNull);
        expect(meta!.takenAt, DateTime(2024, 6, 1, 12, 30, 45));
        expect(meta.latitude, 30.5);
        // GPSLongitudeRef='W' should negate the longitude.
        expect(meta.longitude, -85.3);
        expect(meta.width, 4032);
        expect(meta.height, 3024);
        expect(meta.mimeType, 'image/jpeg');
      },
    );

    test('south latitude flips sign via GPSLatitudeRef=S', () async {
      mockedAttributes = {
        'GPSLatitude': 12.0,
        'GPSLatitudeRef': 'S',
        'GPSLongitude': 45.0,
        'GPSLongitudeRef': 'E',
      };
      final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
      final meta = await ExifExtractor().extract(f);
      expect(meta!.latitude, -12.0);
      expect(meta.longitude, 45.0);
    });

    test(
      'fallback dimension keys ImageWidth/ImageLength when PixelX/Y missing',
      () async {
        mockedAttributes = {
          'ImageWidth': '1920', // string variant
          'ImageLength': 1080, // int variant
        };
        final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
        final meta = await ExifExtractor().extract(f);
        // _parseInt should handle both string and int.
        expect(meta!.width, 1920);
        expect(meta.height, 1080);
      },
    );

    test('returns mtime fallback when getAttributes throws', () async {
      throwOnGetAttributes = true;
      final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
      final meta = await ExifExtractor().extract(f);
      // Plugin parse fails — `takenAt` falls back to mtime, but we still
      // return a non-null metadata so the caller can advance.
      expect(meta, isNotNull);
      expect(meta!.takenAt, isNotNull);
      expect(meta.latitude, isNull);
      expect(meta.longitude, isNull);
      expect(meta.mimeType, 'image/jpeg');
    });

    test('returns mtime fallback when DateTimeOriginal is malformed', () async {
      mockedAttributes = {'DateTimeOriginal': 'not-a-date'};
      final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
      final meta = await ExifExtractor().extract(f);
      expect(meta!.takenAt, isNotNull); // mtime fallback
    });

    test('handles null attributes from getAttributes', () async {
      mockedAttributes = null; // platform returns null
      final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
      final meta = await ExifExtractor().extract(f);
      // No EXIF data at all → mtime fallback for takenAt, no GPS, no dims.
      expect(meta, isNotNull);
      expect(meta!.takenAt, isNotNull);
      expect(meta.latitude, isNull);
      expect(meta.longitude, isNull);
      expect(meta.width, isNull);
      expect(meta.height, isNull);
    });

    test(
      'malformed date with too few parts is rejected (mtime fallback)',
      () async {
        mockedAttributes = {
          'DateTimeOriginal': '2024:06:01', // missing time portion
        };
        final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
        final meta = await ExifExtractor().extract(f);
        expect(meta, isNotNull);
        // Falls through to mtime fallback.
        expect(meta!.takenAt, isNotNull);
        // The mtime should be close to "now" (file was just written).
        expect(
          meta.takenAt!.difference(DateTime.now()).abs(),
          lessThan(const Duration(minutes: 5)),
        );
      },
    );

    test(
      'malformed date with bad date components is rejected (mtime fallback)',
      () async {
        mockedAttributes = {
          'DateTimeOriginal': '2024-06-01 12:30:45', // dashes instead of colons
        };
        final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
        final meta = await ExifExtractor().extract(f);
        expect(meta!.takenAt, isNotNull);
        // mtime fallback rather than the EXIF value.
        expect(meta.takenAt!.year, isNot(2024));
      },
    );

    test(
      'date with non-numeric components triggers FormatException catch',
      () async {
        // Hits the `on FormatException` branch in _parseExifDate, where
        // int.parse on a non-numeric date component throws.
        mockedAttributes = {
          'DateTimeOriginal': 'YYYY:MM:DD HH:MM:SS', // format-correct, parse-broken
        };
        final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
        final meta = await ExifExtractor().extract(f);
        expect(meta!.takenAt, isNotNull); // mtime fallback
      },
    );
  });

  test(
    'large files (>5 MB) take the compute() isolate path',
    () async {
      // Write a 5.1 MB file. The threshold in ExifExtractor is 5 MB; anything
      // larger is dispatched to a background isolate via compute(). We don't
      // assert anything specific about the isolate behaviour — only that the
      // path executes without error and returns a non-null metadata.
      final big = File('${tempDir.path}/big.jpg');
      final bytes = List<int>.filled(5 * 1024 * 1024 + 1024, 0); // 5 MB + 1 KB
      big.writeAsBytesSync(bytes);
      final meta = await ExifExtractor().extract(big);
      // The isolate path uses _extract internally — without a mocked channel
      // (this test is outside the `with mocked native_exif channel` group)
      // the EXIF parse fails and we fall back to mtime.
      expect(meta, isNotNull);
      expect(meta!.takenAt, isNotNull);
      expect(meta.mimeType, 'image/jpeg');
    },
  );
}
