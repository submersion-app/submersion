import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

import 'scan_step_test_support.dart';

/// Test data: USB devices grouped by manufacturer.
final _testUsbDevices = <String, List<DeviceModel>>{
  'Shearwater': [
    const DeviceModel(
      id: 'shearwater_perdix',
      manufacturer: 'Shearwater',
      model: 'Perdix',
      connectionTypes: [DeviceConnectionType.usb],
    ),
    const DeviceModel(
      id: 'shearwater_teric',
      manufacturer: 'Shearwater',
      model: 'Teric',
      connectionTypes: [DeviceConnectionType.usb],
    ),
  ],
  'Suunto': [
    const DeviceModel(
      id: 'suunto_d5',
      manufacturer: 'Suunto',
      model: 'D5',
      connectionTypes: [DeviceConnectionType.usb],
    ),
  ],
  'Mares': [
    const DeviceModel(
      id: 'mares_genius',
      manufacturer: 'Mares',
      model: 'Genius',
      connectionTypes: [DeviceConnectionType.usb],
    ),
  ],
};

Future<void> _switchToUsbTab(WidgetTester tester) async {
  await tester.tap(find.text('USB Cable'));
  await tester.pumpAndSettle();
}

void main() {
  group('USB tab search UI', () {
    testWidgets('shows a search icon button in the USB tab', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      expect(
        find.byIcon(Icons.search),
        findsOneWidget,
        reason: 'USB tab should display a search icon button',
      );
    });

    testWidgets('tapping search icon shows a search text field', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'Tapping search should reveal a text field',
      );
    });

    testWidgets('search filters devices by manufacturer name', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      // All manufacturers visible initially.
      expect(find.text('Shearwater'), findsOneWidget);
      expect(find.text('Suunto'), findsOneWidget);
      expect(find.text('Mares'), findsOneWidget);

      // Activate search and type a manufacturer name.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Suunto');
      await tester.pumpAndSettle();

      // Only Suunto devices should remain; the manufacturer header text
      // appears once in the list (the TextField also contains "Suunto").
      expect(find.text('D5'), findsOneWidget);
      expect(find.text('Shearwater'), findsNothing);
      expect(find.text('Mares'), findsNothing);
    });

    testWidgets('search filters devices by model name', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Perdix');
      await tester.pumpAndSettle();

      // Shearwater header should still be visible (parent of matched model).
      expect(find.text('Shearwater'), findsOneWidget);
      // Perdix appears in both the TextField and the list tile.
      expect(find.text('Perdix'), findsNWidgets(2));
      expect(find.text('Teric'), findsNothing);
      expect(find.text('Suunto'), findsNothing);
      expect(find.text('Mares'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mares');
      await tester.pumpAndSettle();

      expect(find.text('Mares'), findsOneWidget);
      expect(find.text('Genius'), findsOneWidget);
      expect(find.text('Shearwater'), findsNothing);
    });

    testWidgets('clearing search text restores all devices', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Suunto');
      await tester.pumpAndSettle();

      expect(find.text('Shearwater'), findsNothing);

      // Clear the search field.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // All manufacturers should be visible again.
      expect(find.text('Shearwater'), findsOneWidget);
      expect(find.text('Suunto'), findsOneWidget);
      expect(find.text('Mares'), findsOneWidget);
    });

    testWidgets('close button exits search mode', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Tap the close button to exit search.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Search field should be gone, all devices visible.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Shearwater'), findsOneWidget);
      expect(find.text('Suunto'), findsOneWidget);
      expect(find.text('Mares'), findsOneWidget);
    });

    testWidgets('search with no matches shows empty state', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'NonExistentBrand');
      await tester.pumpAndSettle();

      // No manufacturer headers or model names should be visible.
      expect(find.text('Shearwater'), findsNothing);
      expect(find.text('Suunto'), findsNothing);
      expect(find.text('Mares'), findsNothing);

      // Should show some kind of "no results" indication.
      expect(
        find.textContaining('No'),
        findsWidgets,
        reason: 'Should display a no-results message',
      );
    });

    testWidgets('search matches partial text', (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(usbDevices: _testUsbDevices),
      );
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Per');
      await tester.pumpAndSettle();

      // "Per" should match "Perdix".
      expect(find.text('Perdix'), findsOneWidget);
      expect(find.text('Shearwater'), findsOneWidget);
      expect(find.text('Teric'), findsNothing);
      expect(find.text('Suunto'), findsNothing);
    });
  });
}
