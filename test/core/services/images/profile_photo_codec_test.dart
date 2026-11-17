import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/services/images/profile_photo_codec.dart';

/// A solid-colour JPEG of the given size, for feeding the codec.
Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 60, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

img.Image _decode(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  test('a transparent PNG encodes onto white, not black', () {
    // Fully transparent pixels carry rgb 0 and JPEG has no alpha channel.
    // package:image's JPEG encoder blends alpha onto white; this pins that,
    // so a transparent dive center logo never lands on a black square.
    final source = img.Image(width: 64, height: 64, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(0, 0, 0, 0));
    final png = Uint8List.fromList(img.encodePng(source));

    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: png,
        spec: ImageEncodeSpec.avatar,
        declaredName: 'logo.png',
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final centre = _decode(result.bytes!).getPixel(32, 32);
    expect(centre.r, greaterThanOrEqualTo(250));
    expect(centre.g, greaterThanOrEqualTo(250));
    expect(centre.b, greaterThanOrEqualTo(250));
  });

  test('a landscape source becomes a 512x512 square', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1600, 900),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = _decode(result.bytes!);
    expect(out.width, 512);
    expect(out.height, 512);
  });

  test('a portrait source becomes a 512x512 square', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(900, 1600),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 512);
    expect(out.height, 512);
  });

  test('a source smaller than the ceiling is not upscaled', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(200, 200),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 200);
    expect(out.height, 200);
  });

  test('an explicit crop rect selects that region', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1000, 1000),
        spec: ImageEncodeSpec.avatar,
        cropRect: const Rect.fromLTWH(100, 100, 400, 400),
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 400, reason: '400px crop is under the 512 ceiling');
    expect(out.height, 400);
  });

  test('the certification spec preserves aspect ratio', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(4000, 2000),
        spec: ImageEncodeSpec.certificationCard,
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 2000);
    expect(out.height, 1000);
  });

  test('undecodable bytes report undecodable, not a throw', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: Uint8List.fromList([0, 1, 2, 3, 4]),
        spec: ImageEncodeSpec.avatar,
        declaredName: 'broken.jpg',
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.undecodable);
    expect(result.bytes, isNull);
  });

  test('short unnamed bytes report undecodable, not a throw', () {
    // With no name, package:image probes every format, and its PSD probe
    // reads past the end of a short buffer with a RangeError, an Error
    // rather than an Exception.
    for (final bytes in [
      [1, 2],
      [4, 5, 6],
    ]) {
      final result = runImageEncodeRequest(
        ImageEncodeRequest.fromBytes(
          bytes: Uint8List.fromList(bytes),
          spec: ImageEncodeSpec.avatar,
        ),
      );

      expect(result.outcome, ImageEncodeOutcome.undecodable, reason: '$bytes');
      expect(result.bytes, isNull);
    }
  });

  test('a source above maxSourcePixels reports tooLarge', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1000, 1000),
        spec: ImageEncodeSpec.avatar,
        maxSourcePixels: 500 * 500,
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.tooLarge);
    expect(result.bytes, isNull);
  });

  test('the encoded output is a real JPEG under the size budget', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(2000, 2000),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    expect(result.sizeBytes, result.bytes!.length);
    // JPEG SOI marker.
    expect(result.bytes!.sublist(0, 2), [0xFF, 0xD8]);
  });

  test('EXIF orientation 6 is baked before cropping', () {
    // Orientation 6 means "rotate 90 degrees clockwise to display upright".
    // Build a 200x100 image whose LEFT half is red. Displayed upright it is
    // 100x200 with red on TOP, so cropping the top-left 100x100 must come
    // back red. If orientation were baked after the crop, that same rect
    // would select from the unrotated buffer and the result would differ.
    final source = img.Image(width: 200, height: 100);
    img.fill(source, color: img.ColorRgb8(0, 0, 255));
    img.fillRect(
      source,
      x1: 0,
      y1: 0,
      x2: 99,
      y2: 99,
      color: img.ColorRgb8(255, 0, 0),
    );
    source.exif.imageIfd.orientation = 6;
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 95));

    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: bytes,
        spec: ImageEncodeSpec.avatar,
        declaredName: 'rotated.jpg',
        cropRect: const Rect.fromLTWH(0, 0, 100, 100),
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = _decode(result.bytes!);
    final pixel = out.getPixel(50, 50);
    expect(
      pixel.r,
      greaterThan(pixel.b),
      reason:
          'orientation must be baked before the crop is applied, or the '
          'crop selects the wrong region',
    );
  });

  test('PNG bytes decode when no name is declared', () {
    // Contact photos arrive with no filename and are not guaranteed to be
    // JPEG, so they are encoded with declaredName null and the format probed.
    final image = img.Image(width: 300, height: 200);
    img.fill(image, color: img.ColorRgb8(20, 90, 160));
    final png = Uint8List.fromList(img.encodePng(image));

    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(bytes: png, spec: ImageEncodeSpec.avatar),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = _decode(result.bytes!);
    expect(out.width, out.height, reason: 'avatars are square');
  });

  test('a wrong declared extension is why contact photos declare none', () {
    // decodeNamedImage picks the decoder purely by extension and does NOT
    // fall back when that decoder fails, so calling PNG bytes '.jpg' hands
    // them to the JPEG decoder. This pins the hazard the contacts paths avoid.
    final image = img.Image(width: 120, height: 120);
    img.fill(image, color: img.ColorRgb8(20, 90, 160));
    final png = Uint8List.fromList(img.encodePng(image));

    final mislabelled = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: png,
        spec: ImageEncodeSpec.avatar,
        declaredName: 'contact.jpg',
      ),
    );
    final probed = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(bytes: png, spec: ImageEncodeSpec.avatar),
    );

    expect(probed.outcome, ImageEncodeOutcome.encoded);
    expect(
      mislabelled.outcome,
      isNot(ImageEncodeOutcome.encoded),
      reason: 'a wrong extension must not be trusted over the actual bytes',
    );
  });
}
