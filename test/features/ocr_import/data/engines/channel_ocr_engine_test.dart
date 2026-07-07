import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes channel maps into OcrResult', () async {
    const channel = MethodChannel('submersion_ocr');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'recognizeText');
          return [
            {
              'text': 'DEPTH',
              'left': 10.0,
              'top': 20.0,
              'width': 50.0,
              'height': 12.0,
              'confidence': 0.95,
              'imageWidth': 1000.0,
              'imageHeight': 1400.0,
            },
          ];
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final result = await ChannelOcrEngine().recognize(Uint8List(4));
    expect(result.blocks.single.text, 'DEPTH');
    expect(result.blocks.single.boundingBox.left, 10);
    expect(result.blocks.single.confidence, 0.95);
    expect(result.imageSize.width, 1000);
  });

  test('empty channel response yields empty result', () async {
    const channel = MethodChannel('submersion_ocr');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <Object?>[]);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final result = await ChannelOcrEngine().recognize(Uint8List(4));
    expect(result.isEmpty, isTrue);
  });
}
