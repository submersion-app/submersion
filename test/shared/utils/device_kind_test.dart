import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/utils/device_kind.dart';

void main() {
  Future<DeviceKind> kindOn(
    WidgetTester tester,
    TargetPlatform platform,
    Size logicalSize,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.reset);
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
