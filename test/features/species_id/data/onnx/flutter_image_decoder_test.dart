import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/species_id/data/engines/onnx/flutter_image_decoder.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List png(int width, int height) =>
      img.encodePng(img.Image(width: width, height: height));

  testWidgets('applies EXIF orientation', (tester) async {
    // Stored 40 wide and 20 high, to be shown turned a quarter (6).
    final stored = img.Image(width: 40, height: 20);
    stored.exif.imageIfd.orientation = 6;
    final jpeg = img.encodeJpg(stored);

    final decoded = await tester.runAsync(() => decodeForAnalysis(jpeg));

    expect((decoded!.width, decoded.height), (20, 40));
    expect(decoded.bytes, hasLength(20 * 40 * 4));
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
}
