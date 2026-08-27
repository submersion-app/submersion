import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/tesseract_ocr_engine.dart';
import 'package:submersion/features/ocr_import/presentation/providers/ocr_providers.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  ProviderContainer containerFor(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('android, iOS, macOS, and Windows use the plugin channel', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      expect(
        containerFor(platform).read(ocrEngineProvider).runtimeType,
        ChannelOcrEngine,
      );
    }
  });

  test('linux uses Tesseract', () {
    expect(
      containerFor(TargetPlatform.linux).read(ocrEngineProvider).runtimeType,
      TesseractOcrEngine,
    );
  });

  test('availability provider reflects the engine', () async {
    // ChannelOcrEngine reports available unconditionally.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(ocrAvailabilityProvider.future), isTrue);
  });
}
