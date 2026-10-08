import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scan_step_test_support.dart';

/// Issue #2837: iOS has no USB host, so its scan step must not offer a USB
/// tab whose models could never download there.
void main() {
  group('Scan step USB tab', () {
    testWidgets('iOS shows only the Bluetooth scan', (tester) async {
      await tester.pumpWidget(buildScanStepTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.text('USB Cable'), findsNothing);
      expect(find.byIcon(Icons.usb), findsNothing);
      expect(find.text('Looking for Devices'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'platforms with a USB host offer Bluetooth and USB tabs',
      (tester) async {
        await tester.pumpWidget(buildScanStepTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('Bluetooth'), findsOneWidget);
        expect(find.text('USB Cable'), findsOneWidget);

        await tester.tap(find.text('USB Cable'));
        await tester.pumpAndSettle();
        expect(find.text('No USB devices available'), findsOneWidget);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  });
}
