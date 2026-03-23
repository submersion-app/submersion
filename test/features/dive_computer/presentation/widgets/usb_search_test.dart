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
  ) {}
  @override
  void onError(pigeon.DiveComputerError error) {}
  @override
  void onPinCodeRequired(String deviceAddress) {}
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

void main() {
  group('USB tab search UI', () {
    testWidgets('shows a search icon button in the USB tab', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
      await tester.pumpWidget(_buildTestWidget());
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
