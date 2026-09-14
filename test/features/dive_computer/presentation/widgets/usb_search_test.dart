import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart'
    show DownloadEvent;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

/// Fake DiveComputerService that avoids platform channels.
class _FakeDiveComputerService implements pigeon.DiveComputerService {
  @override
  Stream<pigeon.DiscoveredDevice> get discoveredDevices => const Stream.empty();
  @override
  Stream<void> get discoveryComplete => const Stream.empty();
  @override
  Stream<DownloadEvent> get downloadEvents => const Stream.empty();

  @override
  Future<List<pigeon.DeviceDescriptor>> getDeviceDescriptors() async => [];
  @override
  Future<String> getVersion() async => '0.0.0';
  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> startDownload(
    pigeon.DiscoveredDevice device, {
    String? fingerprint,
    bool syncClock = false,
  }) async {}
  @override
  Future<void> cancelDownload() async {}
  @override
  Future<void> submitPinCode(String pinCode) async {}
  @override
  void onDeviceDiscovered(pigeon.DiscoveredDevice device) {}
  @override
  void onDiscoveryComplete() {}
  @override
  void onDownloadProgress(pigeon.DownloadProgress progress) {}
  @override
  void onDiveDownloaded(pigeon.ParsedDive dive) {}
  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
    String? clockSyncStatus,
  ) {}
  @override
  void onError(pigeon.DiveComputerError error) {}
  @override
  void onPinCodeRequired(String deviceAddress) {}
  @override
  void onLogEvent(String category, String level, String message) {}
  @override
  Stream<({String category, String level, String message})> get logEvents =>
      const Stream.empty();
  @override
  void dispose() {}
}

/// DiscoveryNotifier subclass that never triggers platform channel calls.
class _TestDiscoveryNotifier extends DiscoveryNotifier {
  _TestDiscoveryNotifier() : super(service: _FakeDiveComputerService());

  @override
  Future<void> startScan() async {
    // no-op: avoid platform channel calls in tests
  }
}

Widget _buildTestWidget({Map<String, List<DeviceModel>>? usbDevices}) {
  final devices = usbDevices ?? _testUsbDevices;

  return ProviderScope(
    overrides: [
      usbDevicesByManufacturerProvider.overrideWith((ref) async => devices),
      discoveryNotifierProvider.overrideWith((ref) => _TestDiscoveryNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ScanStepWidget(onDeviceSelected: (_) {})),
    ),
  );
}

Future<void> _switchToUsbTab(WidgetTester tester) async {
  await tester.tap(find.text(_l10n(tester).diveComputer_scan_tabUsb));
  await tester.pumpAndSettle();
}

/// Pumps the scan step and opens the USB tab. The default view is tall
/// enough for every group in [_testUsbDevices] to be built, because the
/// sliver list skips rows below the viewport and its cache extent.
Future<void> _pumpUsbTab(
  WidgetTester tester, {
  Map<String, List<DeviceModel>>? usbDevices,
  Size viewSize = const Size(800, 1200),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildTestWidget(usbDevices: usbDevices));
  await tester.pumpAndSettle();
  await _switchToUsbTab(tester);
}

Finder _findSearchField() {
  // The search field has a search prefix icon, whereas the DropdownMenu's TextField does not.
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.prefixIcon != null,
  );
}

/// Scoped to the device list sliver: the dropdown above it keeps an offstage
/// clone of every manufacturer entry, so a wider scope would count those.
Finder _findListItem(String text) {
  return find.descendant(
    of: find.byType(SliverList),
    matching: find.text(text),
  );
}

/// Resolves the localizations the widget under test is rendering with, so
/// assertions follow whichever locale the test platform resolves to.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ScanStepWidget)));

/// Taps the dropdown entry labelled [label]. DropdownMenu builds an offstage
/// clone of every entry (an unkeyed MenuItemButton) purely to measure the
/// widest label; the real, tappable one carries a GlobalKey and is the last
/// match, so a bare find.text(...).last can hit the invisible clone instead.
Future<void> _selectManufacturer(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownMenu<String?>));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('USB tab search UI', () {
    testWidgets('shows a persistent search text field and brand dropdown', (
      tester,
    ) async {
      await _pumpUsbTab(tester);

      expect(
        _findSearchField(),
        findsOneWidget,
        reason: 'USB tab should display a persistent search field',
      );

      expect(
        find.byType(DropdownMenu<String?>),
        findsOneWidget,
        reason: 'USB tab should display a manufacturer dropdown',
      );
    });

    testWidgets('search filters devices by manufacturer name', (tester) async {
      await _pumpUsbTab(tester);

      // All manufacturers visible initially.
      expect(_findListItem('Shearwater'), findsOneWidget);
      expect(_findListItem('Suunto'), findsOneWidget);
      expect(_findListItem('Mares'), findsOneWidget);

      // Activate search and type a manufacturer name.
      await tester.enterText(_findSearchField(), 'Suunto');
      await tester.pumpAndSettle();

      // Only Suunto devices should remain.
      expect(_findListItem('D5'), findsOneWidget);
      expect(_findListItem('Shearwater'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);
    });

    testWidgets('search filters devices by model name', (tester) async {
      await _pumpUsbTab(tester);

      await tester.enterText(_findSearchField(), 'Perdix');
      await tester.pumpAndSettle();

      // Shearwater header should still be visible.
      expect(_findListItem('Shearwater'), findsOneWidget);
      expect(_findListItem('Perdix'), findsOneWidget);
      expect(_findListItem('Teric'), findsNothing);
      expect(_findListItem('Suunto'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await _pumpUsbTab(tester);

      await tester.enterText(_findSearchField(), 'mares');
      await tester.pumpAndSettle();

      expect(_findListItem('Mares'), findsOneWidget);
      expect(_findListItem('Genius'), findsOneWidget);
      expect(_findListItem('Shearwater'), findsNothing);
    });

    testWidgets('clearing search text restores all devices', (tester) async {
      await _pumpUsbTab(tester);

      await tester.enterText(_findSearchField(), 'Suunto');
      await tester.pumpAndSettle();

      expect(_findListItem('Shearwater'), findsNothing);

      // Clear the search field.
      await tester.enterText(_findSearchField(), '');
      await tester.pumpAndSettle();

      // All manufacturers should be visible again.
      expect(_findListItem('Shearwater'), findsOneWidget);
      expect(_findListItem('Suunto'), findsOneWidget);
      expect(_findListItem('Mares'), findsOneWidget);
    });

    testWidgets('search with no matches shows empty state', (tester) async {
      await _pumpUsbTab(tester);

      await tester.enterText(_findSearchField(), 'NonExistentBrand');
      await tester.pumpAndSettle();

      // No manufacturer headers or model names should be visible.
      expect(_findListItem('Shearwater'), findsNothing);
      expect(_findListItem('Suunto'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);

      // The localized no-results message echoes the query back.
      expect(
        find.text(
          _l10n(tester).diveComputer_discovery_usbNoResults('NonExistentBrand'),
        ),
        findsOneWidget,
        reason: 'Should display a no-results message naming the query',
      );
    });

    testWidgets('brand dropdown filters devices by manufacturer', (
      tester,
    ) async {
      await _pumpUsbTab(tester);

      await _selectManufacturer(tester, 'Suunto');

      // Only Suunto devices should remain
      expect(_findListItem('D5'), findsOneWidget);
      expect(_findListItem('Shearwater'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);
    });

    testWidgets('selecting "All computers" clears the brand filter', (
      tester,
    ) async {
      await _pumpUsbTab(tester);

      await _selectManufacturer(tester, 'Suunto');
      expect(_findListItem('Shearwater'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);

      // The reset entry carries a null value, a distinct path from picking
      // a brand, so it must restore every manufacturer group.
      await _selectManufacturer(
        tester,
        _l10n(tester).diveLog_filter_allComputers,
      );

      expect(_findListItem('Shearwater'), findsOneWidget);
      expect(_findListItem('Suunto'), findsOneWidget);
      expect(_findListItem('Mares'), findsOneWidget);
    });

    testWidgets('stacks the brand filter under a full-width search field', (
      tester,
    ) async {
      // A side-by-side row let the dropdown take its widest entry's width
      // and starved the search field, overflowing under large text. Stacked,
      // each control spans the content width regardless of labels or scale.
      const screenWidth = 412.0;
      await _pumpUsbTab(
        tester,
        viewSize: const Size(screenWidth, 800),
        usbDevices: {
          // The widest USB vendor name libdivecomputer ships.
          'Heinrichs Weikamp': [
            const DeviceModel(
              id: 'hw_ostc3',
              manufacturer: 'Heinrichs Weikamp',
              model: 'OSTC 3',
              connectionTypes: [DeviceConnectionType.usb],
            ),
          ],
          ..._testUsbDevices,
        },
      );

      const contentWidth = screenWidth - 2 * 16;
      final search = tester.getRect(_findSearchField());
      final dropdown = tester.getRect(find.byType(DropdownMenu<String?>));

      expect(search.width, contentWidth);
      expect(dropdown.width, contentWidth);
      expect(dropdown.top, greaterThanOrEqualTo(search.bottom));
    });

    testWidgets('scrolls the header away instead of overflowing a short tab', (
      tester,
    ) async {
      // Opening the search field raises the keyboard, which shrinks the tab
      // to roughly this height on a portrait phone; landscape is shorter
      // still. A fixed header above an Expanded list overflows there, so the
      // whole tab scrolls as one and the header can leave the viewport.
      await _pumpUsbTab(tester);
      tester.view.physicalSize = const Size(412, 300);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final search = _findSearchField();
      final searchTop = tester.getRect(search).top;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.getRect(search).top, lessThan(searchTop));
      final viewport = tester.getRect(find.byType(CustomScrollView));
      final firstGroup = tester.getRect(_findListItem('Shearwater'));
      expect(firstGroup.top, greaterThanOrEqualTo(viewport.top));
      expect(firstGroup.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('search matches partial text', (tester) async {
      await _pumpUsbTab(tester);

      await tester.enterText(_findSearchField(), 'Per');
      await tester.pumpAndSettle();

      // "Per" should match "Perdix".
      expect(_findListItem('Perdix'), findsOneWidget);
      expect(_findListItem('Shearwater'), findsOneWidget);
      expect(_findListItem('Teric'), findsNothing);
      expect(_findListItem('Suunto'), findsNothing);
    });
  });
}
