import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart'
    show DownloadEvent;

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake service -- avoids platform channels
// ---------------------------------------------------------------------------

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
  void onLogEvent(String category, String level, String message) {}
  @override
  Stream<({String category, String level, String message})> get logEvents =>
      const Stream.empty();
  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Fake DiveComputerRepository
// ---------------------------------------------------------------------------

class _FakeDiveComputerRepository extends DiveComputerRepository {
  @override
  Future<void> updateComputer(dynamic computer) async {}
  @override
  Future<DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) async => null;
}

/// Repository that never resolves findByBluetoothAddress, simulating
/// an async delay during computer resolution.
class _NeverResolveDiveComputerRepository extends DiveComputerRepository {
  @override
  Future<DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) {
    return Completer<DiveComputer?>().future;
  }

  @override
  Future<void> updateComputer(dynamic computer) async {}
}

// ---------------------------------------------------------------------------
// Test-only DiscoveryNotifier that never touches platform channels
// ---------------------------------------------------------------------------

class _TestDiscoveryNotifier extends DiscoveryNotifier {
  _TestDiscoveryNotifier() : super(service: _FakeDiveComputerService());

  @override
  Future<void> startScan() async {}
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _testDevice = DiscoveredDevice(
  id: 'test-device-1',
  name: 'Shearwater Perdix',
  connectionType: DeviceConnectionType.ble,
  address: 'AA:BB:CC:DD:EE:FF',
  recognizedModel: const DeviceModel(
    id: 'shearwater_perdix',
    manufacturer: 'Shearwater',
    model: 'Perdix',
    connectionTypes: [DeviceConnectionType.ble],
  ),
  discoveredAt: DateTime(2026, 3, 20),
);

final _unrecognizedDevice = DiscoveredDevice(
  id: 'unknown-device',
  name: 'Unknown Gadget',
  connectionType: DeviceConnectionType.ble,
  address: '11:22:33:44:55:66',
  discoveredAt: DateTime(2026, 3, 20),
);

DiveComputer _makeComputer({
  String id = 'computer-1',
  String name = 'My Perdix',
  String? manufacturer = 'Shearwater',
  String? model = 'Perdix',
  String? bluetoothAddress = 'AA:BB:CC:DD:EE:FF',
}) {
  final now = DateTime(2026, 3, 20);
  return DiveComputer(
    id: id,
    name: name,
    manufacturer: manufacturer,
    model: model,
    bluetoothAddress: bluetoothAddress,
    connectionType: 'bluetooth',
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Adapter factory -- constructs a DiveComputerAdapter with fake deps
// ---------------------------------------------------------------------------

/// Creates a [DiveComputerAdapter] backed by fakes suitable for widget tests.
///
/// The adapter's [DiveImportService] and [DiveRepository] are real instances
/// wired to fake repositories; they are never invoked during these widget
/// tests (which only exercise the UI layer).
DiveComputerAdapter _makeAdapter({
  DiveComputer? knownComputer,
  DiveComputerRepository? computerRepository,
}) {
  final repo = computerRepository ?? _FakeDiveComputerRepository();
  return DiveComputerAdapter(
    importService: DiveImportService(repository: repo),
    computerRepository: repo,
    diveRepository: DiveRepository(),
    diverId: 'diver-1',
    knownComputer: knownComputer,
  );
}

// ---------------------------------------------------------------------------
// Widget builders
// ---------------------------------------------------------------------------

/// Creates the common overrides used by all confirm/download step tests.
ProviderScope _scopeWithOverrides({
  required Widget child,
  DiscoveryState? discoveryState,
  DownloadState? downloadState,
}) {
  return ProviderScope(
    overrides: [
      diveComputerServiceProvider.overrideWithValue(_FakeDiveComputerService()),
      diveComputerRepositoryProvider.overrideWithValue(
        _FakeDiveComputerRepository(),
      ),
      discoveryNotifierProvider.overrideWith((ref) {
        final notifier = _TestDiscoveryNotifier();
        if (discoveryState != null) {
          notifier.state = discoveryState;
        }
        return notifier;
      }),
      downloadNotifierProvider.overrideWith((ref) {
        final notifier = DownloadNotifier(
          service: _FakeDiveComputerService(),
          repository: _FakeDiveComputerRepository(),
        );
        if (downloadState != null) {
          notifier.state = downloadState;
        }
        return notifier;
      }),
      usbDevicesByManufacturerProvider.overrideWith(
        (ref) async => <String, List<DeviceModel>>{},
      ),
    ],
    child: child,
  );
}

Widget _buildConfirmStep({
  required DiveComputerAdapter adapter,
  DiscoveryState? discoveryState,
  VoidCallback? onGoBack,
}) {
  return _scopeWithOverrides(
    discoveryState: discoveryState,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DcConfirmDeviceStep(adapter: adapter, onGoBack: onGoBack),
      ),
    ),
  );
}

Widget _buildDownloadStep({
  required DiveComputerAdapter adapter,
  DiveComputer? knownComputer,
  DiscoveryState? discoveryState,
  DownloadState? downloadState,
}) {
  return _scopeWithOverrides(
    discoveryState: discoveryState,
    downloadState: downloadState,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DcAdapterDownloadStep(
          adapter: adapter,
          knownComputer: knownComputer,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // DcAdapterScanStep
  // =========================================================================

  group('DcAdapterScanStep', () {
    testWidgets('renders ScanStepWidget with Bluetooth tab', (tester) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _scopeWithOverrides(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DcAdapterScanStep(adapter: adapter)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ScanStepWidget contains tabs for BLE and USB
      expect(find.text('Bluetooth'), findsOneWidget);
    });
  });

  // =========================================================================
  // DcConfirmDeviceStep
  // =========================================================================

  group('DcConfirmDeviceStep', () {
    testWidgets('shows loading indicator when no device is selected', (
      tester,
    ) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: const DiscoveryState(),
        ),
      );
      // Don't pumpAndSettle -- we want to see the loading state before
      // the post-frame callback resolves.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows device info card for a recognized device', (
      tester,
    ) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pumpAndSettle();

      // Device display name
      expect(find.text('Shearwater Perdix'), findsOneWidget);
      // Manufacturer shown separately
      expect(find.text('Shearwater'), findsOneWidget);
      // Recognized device badge
      expect(find.text('Recognized Device'), findsOneWidget);
    });

    testWidgets('shows warning for unrecognized device', (tester) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _unrecognizedDevice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknown Device'), findsOneWidget);
      expect(
        find.text('This device may not be fully supported.'),
        findsOneWidget,
      );
    });

    testWidgets('shows device name text field for new computer', (
      tester,
    ) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pumpAndSettle();

      // Device Name label text field
      expect(find.text('Device Name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows Connect & Download button', (tester) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect & Download'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('shows Choose Different Device button', (tester) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose Different Device'), findsOneWidget);
    });

    testWidgets('tapping Choose Different Device calls onGoBack callback', (
      tester,
    ) async {
      var goBackCalled = false;
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
          onGoBack: () => goBackCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose Different Device'));
      await tester.pumpAndSettle();

      expect(goBackCalled, isTrue);
    });

    testWidgets(
      'tapping Connect & Download sets confirm can-advance provider',
      (tester) async {
        final adapter = _makeAdapter();

        await tester.pumpWidget(
          _buildConfirmStep(
            adapter: adapter,
            discoveryState: DiscoveryState(selectedDevice: _testDevice),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DcConfirmDeviceStep)),
        );

        expect(container.read(dcAdapterConfirmCanAdvanceProvider), isFalse);

        await tester.tap(find.text('Connect & Download'));
        await tester.pumpAndSettle();

        expect(container.read(dcAdapterConfirmCanAdvanceProvider), isTrue);
      },
    );

    testWidgets('shows bluetooth icon for the device', (tester) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildConfirmStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    });
  });

  // =========================================================================
  // DcAdapterDownloadStep
  // =========================================================================

  group('DcAdapterDownloadStep', () {
    testWidgets('shows loading indicator while resolving computer', (
      tester,
    ) async {
      // When knownComputer is null, the step resolves the computer
      // asynchronously. Before that resolves, it shows a loading indicator.
      final adapter = _makeAdapter(
        computerRepository: _NeverResolveDiveComputerRepository(),
      );

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      // Only pump once to catch the loading state before resolution.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders DownloadStepWidget after computer resolved', (
      tester,
    ) async {
      final computer = _makeComputer();
      final adapter = _makeAdapter(knownComputer: computer);

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          knownComputer: computer,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      // Use pump() -- the DownloadStepWidget contains an indeterminate
      // CircularProgressIndicator that prevents pumpAndSettle from finishing.
      await tester.pump();
      await tester.pump();

      // DownloadStepWidget should be present in the tree.
      expect(find.byType(DownloadStepWidget), findsOneWidget);
    });

    testWidgets('renders DownloadStepWidget after discovery resolution', (
      tester,
    ) async {
      final adapter = _makeAdapter();

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      // Use pump() for the same reason as above.
      await tester.pump();
      await tester.pump();

      // After resolution, the DownloadStepWidget is rendered.
      expect(find.byType(DownloadStepWidget), findsOneWidget);
    });
  });

  // =========================================================================
  // DcNoNewDivesView
  // =========================================================================

  group('DcNoNewDivesView', () {
    testWidgets('shows no new dives message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DcNoNewDivesView(onDone: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('No new dives to download'), findsOneWidget);
      expect(
        find.text('All dives from this computer have already been imported.'),
        findsOneWidget,
      );
    });

    testWidgets('shows check circle icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DcNoNewDivesView(onDone: () {})),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows Done button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DcNoNewDivesView(onDone: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('tapping Done calls onDone callback', (tester) async {
      var doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DcNoNewDivesView(onDone: () => doneCalled = true),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
    });
  });
}
