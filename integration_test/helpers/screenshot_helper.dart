import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
    required this.deviceName,
    this.outputDir = 'screenshots',
  }) {
    // Ensure output directory exists
    final dir = Directory('$outputDir/$deviceName');
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
    // Ensure all frames are rendered
    await tester.pumpAndSettle();

    // Additional wait for async content (charts, maps, images)
    await Future.delayed(settleDuration);

    // Pump again to render any changes from the delay
    await tester.pumpAndSettle();

    _screenshotIndex++;
    final paddedIndex = _screenshotIndex.toString().padLeft(2, '0');
    final filename = '${deviceName}_${paddedIndex}_$name';

    // Capture screenshot bytes and save to file
    final bytes = await binding.takeScreenshot(filename);
    final file = File('$outputDir/$deviceName/$filename.png');
    await file.writeAsBytes(bytes);

    // Log for visibility during test runs
    // ignore: avoid_print
    print('📸 Screenshot saved: ${file.path}');
  }

  /// Waits for content to load with visual feedback.
  ///
  /// Use this before taking screenshots of screens with async data loading.
  Future<void> waitForContent(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    await tester.pumpAndSettle();
    await Future.delayed(duration);
    await tester.pumpAndSettle();
  }

  /// Gets the device name from environment or platform detection.
  static String getDeviceName() {
    // Check environment variable first (set by capture script)
    final envDeviceName = Platform.environment['SCREENSHOT_DEVICE_NAME'];
    if (envDeviceName != null && envDeviceName.isNotEmpty) {
      return envDeviceName;
    }

    // Default fallback
    return 'device';
  }
}
