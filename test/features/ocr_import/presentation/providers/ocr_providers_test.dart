import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/mlkit_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/tesseract_ocr_engine.dart';
import 'package:submersion/features/ocr_import/presentation/providers/ocr_providers.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Type engineFor(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(ocrEngineProvider).runtimeType;
  }

  test('android uses ML Kit', () {
    expect(engineFor(TargetPlatform.android), MlkitOcrEngine);
  });

  test('iOS, macOS, and Windows use the plugin channel', () {
    expect(engineFor(TargetPlatform.iOS), ChannelOcrEngine);
    expect(engineFor(TargetPlatform.macOS), ChannelOcrEngine);
    expect(engineFor(TargetPlatform.windows), ChannelOcrEngine);
  });

  test('linux uses Tesseract', () {
    expect(engineFor(TargetPlatform.linux), TesseractOcrEngine);
  });
}
