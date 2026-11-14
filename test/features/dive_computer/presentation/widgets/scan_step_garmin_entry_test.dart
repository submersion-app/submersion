import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/garmin_watch_usb_entry.dart';

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

  /// Scoped to the device list: the brand dropdown keeps an offstage clone
  /// of every brand name.
  Finder inList(String text) =>
      find.descendant(of: find.byType(SliverList), matching: find.text(text));

  /// Every brand starts folded (issue #4480); a tap on its heading opens it.
  Future<void> openBrand(WidgetTester tester, String brand) async {
    await tester.tap(inList(brand));
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

    // Garmin is a brand like any other: folded until its heading is tapped.
    expect(inList('Garmin'), findsOneWidget);
    expect(find.text(entryLabel), findsNothing);

    await openBrand(tester, 'Garmin');
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

    await openBrand(tester, 'Shearwater');
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

      expect(inList('Garmin'), findsNothing);
      await openBrand(tester, 'Shearwater');
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

    expect(inList('Garmin'), findsNothing);
    expect(find.text(entryLabel), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  group('where the entry goes in the list', () {
    DeviceModel model(String manufacturer, String name) => DeviceModel(
      id: '${manufacturer}_$name',
      manufacturer: manufacturer,
      model: name,
      connectionTypes: const [DeviceConnectionType.usb],
    );

    test('Garmin takes its alphabetical place among the brands', () {
      // The list is sorted by brand (issue #4480); appended at the end,
      // Garmin sat below Zeagle.
      final devices = GarminWatchUsbEntry.addTo({
        'Aqualung': [model('Aqualung', 'i300')],
        'Mares': [model('Mares', 'Genius')],
        'Zeagle': [model('Zeagle', 'N2iTiON3')],
      }, label: entryLabel);

      expect(devices.keys, ['Aqualung', 'Garmin', 'Mares', 'Zeagle']);
      expect(devices['Garmin']!.single.model, entryLabel);
      expect(GarminWatchUsbEntry.isEntry(devices['Garmin']!.single), isTrue);
    });

    test('goes last when every brand sorts before it, and alone when none', () {
      expect(
        GarminWatchUsbEntry.addTo({
          'Aqualung': [model('Aqualung', 'i300')],
        }, label: entryLabel).keys,
        ['Aqualung', 'Garmin'],
      );
      expect(GarminWatchUsbEntry.addTo(const {}, label: entryLabel).keys, [
        'Garmin',
      ]);
    });

    test('joins a Garmin brand that is already listed, keeping its place', () {
      final devices = GarminWatchUsbEntry.addTo({
        'Garmin': [model('Garmin', 'Descent Mk1')],
        'Mares': [model('Mares', 'Genius')],
      }, label: entryLabel);

      expect(devices.keys, ['Garmin', 'Mares']);
      expect(devices['Garmin']!.map((m) => m.model), [
        'Descent Mk1',
        entryLabel,
      ]);
    });
  });
}
