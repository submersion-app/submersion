import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Compile-time constants passed via --dart-define from the capture script.
/// These are needed because environment variables don't cross the host→simulator boundary.
const String _kOutputDir = String.fromEnvironment(
  'SCREENSHOT_OUTPUT_DIR',
  defaultValue: 'screenshots',
);
const String _kDeviceName = String.fromEnvironment(
  'SCREENSHOT_DEVICE_NAME',
  defaultValue: 'device',
);

/// Helper class for capturing screenshots during integration tests.
///
/// This helper manages screenshot capture with consistent naming conventions
/// and handles the async nature of Flutter's rendering pipeline.
class ScreenshotHelper {
  final IntegrationTestWidgetsFlutterBinding binding;
  final String deviceName;
  final String outputDir;

  int _screenshotIndex = 0;

  ScreenshotHelper({
    required this.binding,
    String? deviceName,
    String? outputDir,
  }) : deviceName = deviceName ?? _kDeviceName,
       outputDir = outputDir ?? _kOutputDir {
    // Ensure output directory exists
    final dir = Directory('${this.outputDir}/${this.deviceName}');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  /// Takes a screenshot with the given name.
  ///
  /// The screenshot is saved with a prefix based on the device name and
  /// an incrementing index to maintain order.
  ///
  /// Example filename: `iPhone_6_7_inch/iPhone_6_7_inch_01_dashboard.png`
  Future<void> takeScreenshot(
    WidgetTester tester,
    String name, {
    Duration settleDuration = const Duration(milliseconds: 500),
  }) async {
    // Pump multiple frames to allow layout to complete.
    // We avoid pumpAndSettle() because infinite animations (e.g. HeroHeader
    // ocean effect) would cause it to hang indefinitely.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Additional wait for async content (charts, maps, images)
    await Future.delayed(settleDuration);

    // Pump again to render any changes from the delay
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    _screenshotIndex++;
    final paddedIndex = _screenshotIndex.toString().padLeft(2, '0');
    final filename = '${deviceName}_${paddedIndex}_$name';

    // Capture screenshot bytes and save to file.
    // On desktop (macOS/Windows/Linux), the integration_test platform channel
    // for captureScreenshot is not implemented. Use Flutter's rendering pipeline
    // directly via OffsetLayer.toImage() instead.
    final List<int> bytes;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      bytes = await _captureViaRenderPipeline(tester);
    } else {
      bytes = await binding.takeScreenshot(filename);
    }
    final file = File('$outputDir/$deviceName/$filename.png');
    await file.writeAsBytes(bytes);

    // Log for visibility during test runs
    // ignore: avoid_print
    print('📸 Screenshot saved: ${file.path}');
  }

  /// Captures a screenshot using Flutter's rendering pipeline.
  /// This works on all platforms (including desktop) without needing the
  /// integration_test platform channel.
  Future<List<int>> _captureViaRenderPipeline(WidgetTester tester) async {
    final renderView = tester.binding.renderViews.first;
    final layer = renderView.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      renderView.paintBounds,
      pixelRatio: tester.view.devicePixelRatio,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  /// Waits for content to load with visual feedback.
  ///
  /// Use this before taking screenshots of screens with async data loading.
  Future<void> waitForContent(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await Future.delayed(duration);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}
