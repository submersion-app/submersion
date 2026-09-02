import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/services/images/profile_photo_codec.dart';

/// Guards the contract certification photos rely on: the cap is enforced in
/// Dart, not by ImagePicker's maxWidth / maxHeight / imageQuality, which
/// image_picker_macos, image_picker_windows and image_picker_linux all
/// document as silently ignored.
Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 200, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  test('an oversized card photo is bounded to 2000px on any platform', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(6000, 4000),
        spec: ImageEncodeSpec.certificationCard,
        declaredName: 'card.jpg',
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = img.decodeImage(result.bytes!)!;
    expect(out.width, 2000);
    expect(
      out.height,
      closeTo(1333, 1),
      reason: 'aspect ratio must be preserved',
    );
  });

  test('a card photo is not cropped to a square', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1000, 600),
        spec: ImageEncodeSpec.certificationCard,
        declaredName: 'card.jpg',
      ),
    );

    final out = img.decodeImage(result.bytes!)!;
    expect(out.width, 1000);
    expect(out.height, 600);
  });

  test('the card ceiling is higher than the avatar ceiling', () {
    // Card text must stay readable, which an avatar does not need.
    expect(
      ImageEncodeSpec.certificationCard.maxDimension,
      greaterThan(ImageEncodeSpec.avatar.maxDimension),
    );
    expect(ImageEncodeSpec.certificationCard.square, isFalse);
    expect(ImageEncodeSpec.avatar.square, isTrue);
  });
}
