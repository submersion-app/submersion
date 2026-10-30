import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/utils/device_kind.dart';

void main() {
  /// [logicalSize] is the display; [window] the app's window on it, the
  /// whole display unless given.
  Future<DeviceKind> kindOn(
    WidgetTester tester,
    TargetPlatform platform,
    Size logicalSize, {
    Size? window,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window ?? logicalSize;
    tester.view.display.devicePixelRatio = 1;
    tester.view.display.size = logicalSize;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    late DeviceKind kind;
    // Reset before the test ends: the binding checks foundation debug
    // variables before tear-downs run.
    debugDefaultTargetPlatformOverride = platform;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              kind = deviceKindOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    return kind;
  }

  testWidgets('a narrow Android screen is a phone', (tester) async {
    expect(
      await kindOn(tester, TargetPlatform.android, const Size(390, 844)),
      DeviceKind.phone,
    );
  });

  testWidgets('a wide iOS screen is a tablet', (tester) async {
    expect(
      await kindOn(tester, TargetPlatform.iOS, const Size(820, 1180)),
      DeviceKind.tablet,
    );
  });

  // Issue #3482 review: the word names the device, not the window; a
  // tablet in Slide Over or a narrow split is still a tablet.
  testWidgets('a tablet in a narrow window is still a tablet', (tester) async {
    expect(
      await kindOn(
        tester,
        TargetPlatform.iOS,
        const Size(820, 1180),
        window: const Size(320, 1180),
      ),
      DeviceKind.tablet,
    );
  });

  testWidgets('a desktop platform is a computer, whatever its size', (
    tester,
  ) async {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        await kindOn(tester, platform, const Size(500, 700)),
        DeviceKind.computer,
      );
    }
  });

  testWidgets('a platform it cannot tell apart is a device', (tester) async {
    expect(
      await kindOn(tester, TargetPlatform.fuchsia, const Size(390, 844)),
      DeviceKind.other,
    );
  });

  test('the select argument names each kind', () {
    expect(DeviceKind.values.map(deviceKindArg), [
      'phone',
      'tablet',
      'computer',
      'other',
    ]);
  });
}
