import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scan_step_test_support.dart';

/// Shrinks the test view to [size] at a 1:1 pixel ratio and restores the
/// defaults when the test ends.
void _useViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Bluetooth tab empty state', () {
    for (final size in const [Size(412, 400), Size(412, 300)]) {
      testWidgets('does not overflow in a ${size.height.toInt()}px tall view', (
        tester,
      ) async {
        _useViewSize(tester, size);

        await tester.pumpWidget(buildScanStepTestWidget());
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'the empty state should yield height instead of overflowing '
              'the Bluetooth tab',
        );
      });
    }
  });
}
