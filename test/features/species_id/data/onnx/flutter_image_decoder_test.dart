import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/species_id/data/engines/onnx/flutter_image_decoder.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import 'icc_test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List png(int width, int height) =>
      img.encodePng(img.Image(width: width, height: height));

  testWidgets('applies EXIF orientation', (tester) async {
    // Stored 40 wide and 20 high, to be shown turned a quarter clockwise
    // (6): its red left edge is shown along the top, as the viewer shows it,
    // so boxes land on the fish where the diver sees it.
    final stored = img.Image(width: 40, height: 20);
    img.fillRect(
      stored,
      x1: 0,
      y1: 0,
      x2: 9,
      y2: 19,
      color: img.ColorRgb8(255, 0, 0),
    );
    stored.exif.imageIfd.orientation = 6;
    final jpeg = img.encodeJpg(stored, quality: 100);

    final decoded = await tester.runAsync(() => decodeForAnalysis(jpeg));

    expect((decoded!.width, decoded.height), (20, 40));
    expect(decoded.bytes, hasLength(20 * 40 * 4));
    int red(int x, int y) => decoded.bytes[(y * decoded.width + x) * 4];
    expect(red(10, 4), greaterThan(200), reason: 'the red edge is on top');
    expect(red(10, 35), lessThan(50), reason: 'not at the bottom');
  });

  testWidgets('caps the longer side at 4096', (tester) async {
    final decoded = await tester.runAsync(
      () => decodeForAnalysis(png(8000, 2000)),
    );

    expect((decoded!.width, decoded.height), (4096, 1024));
  });

  testWidgets('leaves a small image as it is', (tester) async {
    final decoded = await tester.runAsync(
      () => decodeForAnalysis(png(300, 200)),
    );

    expect((decoded!.width, decoded.height), (300, 200));
  });

  testWidgets('unreadable bytes fail with decode_failed', (tester) async {
    Object? error;
    await tester.runAsync(() async {
      try {
        await decodeForAnalysis(Uint8List.fromList([1, 2, 3, 4]));
      } on Object catch (e) {
        error = e;
      }
    });

    expect(
      error,
      isA<VisionEngineException>().having(
        (e) => e.code,
        'code',
        'decode_failed',
      ),
    );
  });

  testWidgets('carries the conversion of an embedded colour profile, '
      'which Flutter does not apply', (tester) async {
    final decoded = await tester.runAsync(
      () => decodeForAnalysis(jpegWith(displayP3Profile())),
    );

    expect(decoded!.colour, isNotNull);
    // Flutter's decoder hands back the stored values, unconverted.
    expect(decoded.bytes[0], closeTo(200, 2));
  });

  testWidgets('a photo with no colour profile carries no conversion', (
    tester,
  ) async {
    final decoded = await tester.runAsync(
      () => decodeForAnalysis(jpegWith(null)),
    );
    expect(decoded!.colour, isNull);
  });
}
