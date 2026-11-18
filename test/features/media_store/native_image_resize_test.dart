import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:submersion/features/media_store/data/image_resize_job.dart';
import 'package:submersion/features/media_store/data/native_image_resize.dart';

/// Thumbnail production through Flutter's own decoder (issue #3337), with
/// the Dart decoder kept behind it for the formats the engine rejects.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('native_image_resize_test');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  String out(String name) => p.join(root.path, name);

  File writePng(String name, {required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(20, 80, 140));
    return File(out(name))..writeAsBytesSync(img.encodePng(image));
  }

  ImageResizeRequest fromFile(
    File source,
    String destination, {
    bool skipWhenUnderCeiling = false,
  }) => ImageResizeRequest.fromFile(
    sourcePath: source.path,
    destinationPath: destination,
    declaredName: p.basename(source.path),
    maxDimension: 512,
    jpegQuality: 80,
    skipWhenUnderCeiling: skipWhenUnderCeiling,
  );

  Future<ImageResizeResult> neverFallBack(ImageResizeRequest _) async =>
      fail('the Dart decoder must not run when the native one succeeds');

  test('a file is written as a JPEG 512 on its longest edge, keeping its '
      'shape, without the Dart decoder', () async {
    final source = writePng('wide.png', width: 2000, height: 1000);
    final destination = out('thumb.jpg');

    final result = await resizeToJpegFileNative(
      fromFile(source, destination),
      fallback: neverFallBack,
    );

    expect(result.outcome, ImageResizeOutcome.written);
    final bytes = File(destination).readAsBytesSync();
    expect(result.sizeBytes, bytes.length);
    expect(bytes.take(2).toList(), [0xFF, 0xD8]);
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, 512);
    expect(decoded.height, 256);
  });

  test('a portrait source is bounded on its height', () async {
    final source = writePng('tall.png', width: 600, height: 1200);
    final destination = out('thumb.jpg');

    await resizeToJpegFileNative(
      fromFile(source, destination),
      fallback: neverFallBack,
    );

    final decoded = img.decodeJpg(File(destination).readAsBytesSync())!;
    expect(decoded.height, 512);
    expect(decoded.width, 256);
  });

  test('bytes are resized the same way', () async {
    final source = writePng('wide.png', width: 1024, height: 768);
    final destination = out('thumb.jpg');

    final result = await resizeToJpegFileNative(
      ImageResizeRequest.fromBytes(
        bytes: source.readAsBytesSync(),
        destinationPath: destination,
        declaredName: 'wide.png',
        maxDimension: 512,
        jpegQuality: 80,
      ),
      fallback: neverFallBack,
    );

    expect(result.outcome, ImageResizeOutcome.written);
    final decoded = img.decodeJpg(File(destination).readAsBytesSync())!;
    expect(decoded.width, 512);
    expect(decoded.height, 384);
  });

  test('a small source is re-encoded without being enlarged', () async {
    final source = writePng('small.png', width: 64, height: 48);
    final destination = out('thumb.jpg');

    final result = await resizeToJpegFileNative(
      fromFile(source, destination),
      fallback: neverFallBack,
    );

    expect(result.outcome, ImageResizeOutcome.written);
    final decoded = img.decodeJpg(File(destination).readAsBytesSync())!;
    expect(decoded.width, 64);
    expect(decoded.height, 48);
  });

  group('a JPEG source\'s EXIF (#4699)', () {
    File writeJpegWithExif(String name) {
      final image = img.Image(width: 1200, height: 800);
      img.fill(image, color: img.ColorRgb8(20, 80, 140));
      image.exif.exifIfd['DateTimeOriginal'] = img.IfdValueAscii(
        '2026:01:02 03:04:05',
      );
      image.exif.imageIfd['Orientation'] = img.IfdValueShort(6);
      return File(out(name))..writeAsBytesSync(img.encodeJpg(image));
    }

    test('is carried over, less its orientation, when the request keeps '
        'it', () async {
      // A compressed upload replaced package:image's re-encode, which kept
      // the capture time and location; the engine applies the orientation
      // as it decodes, so the tag would turn the pixels a second time.
      final source = writeJpegWithExif('dated.jpg');
      final destination = out('rendition.jpg');

      await resizeToJpegFileNative(
        ImageResizeRequest.fromFile(
          sourcePath: source.path,
          destinationPath: destination,
          declaredName: 'dated.jpg',
          maxDimension: 512,
          jpegQuality: 80,
          keepJpegMetadata: true,
        ),
        fallback: neverFallBack,
      );

      final exif = img.decodeJpgExif(File(destination).readAsBytesSync())!;
      expect(
        exif.exifIfd['DateTimeOriginal']?.toString(),
        '2026:01:02 03:04:05',
      );
      expect(exif.imageIfd['Orientation'], isNull);
    });

    test('is carried over from bytes too', () async {
      final source = writeJpegWithExif('dated.jpg');
      final destination = out('rendition.jpg');

      await resizeToJpegFileNative(
        ImageResizeRequest.fromBytes(
          bytes: source.readAsBytesSync(),
          destinationPath: destination,
          declaredName: 'dated.jpg',
          maxDimension: 512,
          jpegQuality: 80,
          keepJpegMetadata: true,
        ),
        fallback: neverFallBack,
      );

      final exif = img.decodeJpgExif(File(destination).readAsBytesSync())!;
      expect(
        exif.exifIfd['DateTimeOriginal']?.toString(),
        '2026:01:02 03:04:05',
      );
    });

    test('is left behind for a thumbnail', () async {
      final source = writeJpegWithExif('dated.jpg');
      final destination = out('thumb.jpg');

      await resizeToJpegFileNative(
        fromFile(source, destination),
        fallback: neverFallBack,
      );

      final exif = img.decodeJpgExif(File(destination).readAsBytesSync());
      expect(exif?.exifIfd['DateTimeOriginal'], isNull);
    });
  });

  test('skipWhenUnderCeiling leaves a small source alone', () async {
    final source = writePng('small.png', width: 64, height: 48);
    final destination = out('thumb.jpg');

    final result = await resizeToJpegFileNative(
      fromFile(source, destination, skipWhenUnderCeiling: true),
      fallback: neverFallBack,
    );

    expect(result.outcome, ImageResizeOutcome.underCeiling);
    expect(File(destination).existsSync(), isFalse);
  });

  test(
    'a source the native decoder rejects goes to the Dart decoder',
    () async {
      final source = writePng('odd.png', width: 900, height: 600);
      final destination = out('thumb.jpg');
      var fallbacks = 0;

      final result = await resizeToJpegFileNative(
        fromFile(source, destination),
        decode: (_) async => throw Exception('unsupported format'),
        fallback: (request) {
          fallbacks++;
          return resizeToJpegFile(request);
        },
      );

      expect(fallbacks, 1);
      expect(result.outcome, ImageResizeOutcome.written);
      final decoded = img.decodeJpg(File(destination).readAsBytesSync())!;
      expect(decoded.width, 512);
    },
  );

  test('bytes neither decoder can read are undecodable and write '
      'nothing', () async {
    final junk = File(out('junk.png'))..writeAsBytesSync([1, 2, 3, 4]);
    final destination = out('thumb.jpg');

    final result = await resizeToJpegFileNative(fromFile(junk, destination));

    expect(result.outcome, ImageResizeOutcome.undecodable);
    expect(File(destination).existsSync(), isFalse);
  });
}
