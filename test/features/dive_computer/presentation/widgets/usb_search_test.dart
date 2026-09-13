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
  await tester.tap(find.text('USB Cable'));
  await tester.pumpAndSettle();
}

Finder _findSearchField() {
  // The search field has a search prefix icon, whereas the DropdownMenu's TextField does not.
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.prefixIcon != null,
  );
}

Finder _findListItem(String text) {
  return find.descendant(of: find.byType(ListView), matching: find.text(text));
}

void main() {
  group('USB tab search UI', () {
    testWidgets('shows a persistent search text field and brand dropdown', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

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
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

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
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

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
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.enterText(_findSearchField(), 'mares');
      await tester.pumpAndSettle();

      expect(_findListItem('Mares'), findsOneWidget);
      expect(_findListItem('Genius'), findsOneWidget);
      expect(_findListItem('Shearwater'), findsNothing);
    });

    testWidgets('clearing search text restores all devices', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

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
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      await tester.enterText(_findSearchField(), 'NonExistentBrand');
      await tester.pumpAndSettle();

      // No manufacturer headers or model names should be visible.
      expect(_findListItem('Shearwater'), findsNothing);
      expect(_findListItem('Suunto'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);

      // Should show some kind of "no results" indication.
      expect(
        find.textContaining('No'),
        findsWidgets,
        reason: 'Should display a no-results message',
      );
    });

    testWidgets('brand dropdown filters devices by manufacturer', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

      // Tap the dropdown to open menu
      await tester.tap(find.byType(DropdownMenu<String?>));
      await tester.pumpAndSettle();

      // Tap on 'Suunto'. DropdownMenu builds an offstage clone of every
      // entry (an unkeyed MenuItemButton) purely to measure the widest
      // label; the real, tappable one carries a GlobalKey and is the last
      // match, so a bare find.text(...).last can hit the invisible clone
      // instead.
      await tester.tap(find.widgetWithText(MenuItemButton, 'Suunto').last);
      await tester.pumpAndSettle();

      // Only Suunto devices should remain
      expect(_findListItem('D5'), findsOneWidget);
      expect(_findListItem('Shearwater'), findsNothing);
      expect(_findListItem('Mares'), findsNothing);
    });

    testWidgets('search matches partial text', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await _switchToUsbTab(tester);

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
