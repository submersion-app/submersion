import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/corrected_photo_encoder.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';

/// A 40x20 blue JPEG stamped with a capture time, GPS and [orientation].
Uint8List jpegWithExif({int orientation = 1}) {
  final im = img.Image(width: 40, height: 20)
    ..clear(img.ColorRgb8(30, 100, 160));
  im.exif.imageIfd.orientation = orientation;
  im.exif.exifIfd['DateTimeOriginal'] = img.IfdValueAscii(
    '2026:07:01 10:20:00',
  );
  im.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  return Uint8List.fromList(img.encodeJpg(im, quality: 95));
}

double meanRed(img.Image im) {
  var sum = 0.0;
  for (final p in im) {
    sum += p.r;
  }
  return sum / (im.width * im.height);
}

/// Issue #3520: a shared photo carries its colour correction.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applies the matrix and keeps the capture details', () async {
    final source = jpegWithExif();
    final out = await encodeCorrectedPhoto(
      bytes: source,
      matrix: ColorMatrix.warmth(1),
      filename: 'reef.jpg',
      mime: 'image/jpeg',
    );
    expect(out, isNotNull);
    expect(out!.filename, 'reef.jpg');
    final decoded = img.decodeJpg(out.bytes)!;
    expect(meanRed(decoded), greaterThan(meanRed(img.decodeJpg(source)!) + 5));
    expect(
      decoded.exif.exifIfd['DateTimeOriginal']?.toString(),
      '2026:07:01 10:20:00',
    );
    expect(decoded.exif.gpsIfd['GPSLatitudeRef']?.toString(), 'N');
  });

  test('pixels are stored upright, so orientation is reset to 1', () async {
    final out = await encodeCorrectedPhoto(
      bytes: jpegWithExif(orientation: 6),
      matrix: ColorMatrix.warmth(1),
      filename: 'reef.jpg',
      mime: 'image/jpeg',
    );
    // decodeJpg applies and clears the tag, so read the raw EXIF.
    expect(img.decodeJpgExif(out!.bytes)!.imageIfd.orientation, 1);
    final decoded = img.decodeJpg(out.bytes)!;
    // Orientation 6 is a quarter turn: the 40x20 sensor image is 20x40.
    expect((decoded.width, decoded.height), (20, 40));
  });

  test('any other format is shared as a JPEG', () async {
    final png = Uint8List.fromList(
      img.encodePng(
        img.Image(width: 8, height: 8)..clear(img.ColorRgb8(30, 100, 160)),
      ),
    );
    final out = await encodeCorrectedPhoto(
      bytes: png,
      matrix: ColorMatrix.warmth(1),
      filename: 'IMG_0042.png',
      mime: 'image/png',
    );
    expect(out!.filename, 'IMG_0042.jpg');
    expect(img.decodeJpg(out.bytes), isNotNull);
  });

  test('a corrupt file gives null, so the original is shared', () async {
    expect(
      await encodeCorrectedPhoto(
        bytes: Uint8List.fromList([1, 2, 3]),
        matrix: ColorMatrix.warmth(1),
        filename: 'x.jpg',
        mime: 'image/jpeg',
      ),
      isNull,
    );
  });
}
