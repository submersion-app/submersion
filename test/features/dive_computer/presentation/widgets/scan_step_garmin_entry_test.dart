import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

import 'scan_step_test_support.dart';

/// Issue #4223: on Windows the USB list offers Garmin, which opens the
/// Garmin device import instead of a libdivecomputer download.
void main() {
  const entryLabel = 'Garmin watch (Descent, Fenix, Epix...)';

  const shearwater = DeviceModel(
    id: 'Shearwater_Petrel_3',
    manufacturer: 'Shearwater',
    model: 'Petrel',
    connectionTypes: [DeviceConnectionType.usb],
    dcModel: 3,
  );
  const usbDevices = {
    'Shearwater': [shearwater],
  };

  Future<void> openUsbTab(WidgetTester tester) async {
    await tester.tap(find.text('USB Cable'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
  }

  testWidgets('Windows lists Garmin, and picking it never starts a download', (
    tester,
  ) async {
    var garminPicks = 0;
    final downloads = <DiscoveredDevice>[];
    await tester.pumpWidget(
      buildScanStepTestWidget(
        usbDevices: usbDevices,
        onDeviceSelected: downloads.add,
        onGarminWatchSelected: () => garminPicks++,
      ),
    );
    await tester.pumpAndSettle();
    await openUsbTab(tester);

    expect(find.text('Garmin'), findsOneWidget);
    expect(find.text(entryLabel), findsOneWidget);

    await tester.tap(find.text(entryLabel));
    await tester.pumpAndSettle();

    expect(garminPicks, 1);
    expect(downloads, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a libdivecomputer model still goes to the download', (
    tester,
  ) async {
    var garminPicks = 0;
    final downloads = <DiscoveredDevice>[];
    await tester.pumpWidget(
      buildScanStepTestWidget(
        usbDevices: usbDevices,
        onDeviceSelected: downloads.add,
        onGarminWatchSelected: () => garminPicks++,
      ),
    );
    await tester.pumpAndSettle();
    await openUsbTab(tester);

    await tester.tap(find.text('Petrel'));
    await tester.pumpAndSettle();

    expect(downloads.single.recognizedModel, shearwater);
    expect(garminPicks, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('searching "descent" or "garmin" finds the entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScanStepTestWidget(
        usbDevices: usbDevices,
        onGarminWatchSelected: () {},
      ),
    );
    await tester.pumpAndSettle();
    await openUsbTab(tester);

    await search(tester, 'descent');
    expect(find.text(entryLabel), findsOneWidget);
    expect(find.text('Petrel'), findsNothing);

    await search(tester, 'garmin');
    expect(find.text(entryLabel), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'other platforms have no Garmin entry',
    (tester) async {
      await tester.pumpWidget(
        buildScanStepTestWidget(
          usbDevices: usbDevices,
          onGarminWatchSelected: () {},
        ),
      );
      await tester.pumpAndSettle();
      await openUsbTab(tester);

      expect(find.text(entryLabel), findsNothing);
      expect(find.text('Petrel'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );

  testWidgets('without a Garmin callback there is no Garmin entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildScanStepTestWidget(usbDevices: usbDevices));
    await tester.pumpAndSettle();
    await openUsbTab(tester);

    expect(find.text(entryLabel), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
