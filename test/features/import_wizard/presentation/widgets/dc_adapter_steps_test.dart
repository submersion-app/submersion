import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart'
    show DownloadEvent;
// flutter_riverpod 3 no longer re-exports Override.
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;

import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
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

/// Repository that records the computers created through it, so a test can
/// assert that a download persisted the dive computer it talked to.
class _RecordingDiveComputerRepository extends DiveComputerRepository {
  final List<DiveComputer> created = [];

  @override
  Future<DiveComputer> createComputer(DiveComputer computer) async {
    created.add(computer);
    return computer;
  }

  @override
  Future<void> updateComputer(dynamic computer) async {}

  @override
  Future<DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) async => null;

  @override
  Future<DiveComputer?> findByHardwareIdentity({
    required String manufacturer,
    required String model,
    required String serialNumber,
    String? diverId,
  }) async => null;
}

/// Repository whose computer save fails, standing in for any database error
/// while the download step records the computer it just talked to.
class _FailingCreateDiveComputerRepository extends DiveComputerRepository {
  @override
  Future<DiveComputer> createComputer(DiveComputer computer) async {
    throw StateError('database is locked');
  }

  @override
  Future<void> updateComputer(dynamic computer) async {}

  @override
  Future<DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) async => null;

  @override
  Future<DiveComputer?> findByHardwareIdentity({
    required String manufacturer,
    required String model,
    required String serialNumber,
    String? diverId,
  }) async => null;
}

/// Repository whose computer save runs [onCreate], so a test can fail the
/// first attempt and let a retry succeed.
class _FlakyCreateDiveComputerRepository extends DiveComputerRepository {
  _FlakyCreateDiveComputerRepository(this.onCreate);

  final DiveComputer Function() onCreate;

  @override
  Future<DiveComputer> createComputer(DiveComputer computer) async =>
      onCreate();

  @override
  Future<void> updateComputer(dynamic computer) async {}

  @override
  Future<DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) async => null;

  @override
  Future<DiveComputer?> findByHardwareIdentity({
    required String manufacturer,
    required String model,
    required String serialNumber,
    String? diverId,
  }) async => null;
}

/// Clock sync settings whose write fails, as a SharedPreferences error would.
class _FailingClockSyncSettingsNotifier extends ClockSyncSettingsNotifier {
  _FailingClockSyncSettingsNotifier() : super.unstored();

  @override
  Future<void> recordSupport(String computerId, ClockSyncStatus status) async {
    throw StateError('preferences unavailable');
  }
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
  WidgetRef? ref,
}) {
  final repo = computerRepository ?? _FakeDiveComputerRepository();
  final diveRepository = DiveRepository();
  return DiveComputerAdapter(
    importService: DiveImportService(repository: repo),
    computerRepository: repo,
    diveRepository: diveRepository,
    consolidationService: DiveConsolidationService(diveRepository),
    diverId: 'diver-1',
    knownComputer: knownComputer,
    ref: ref,
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
  List<riverpod.Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...extraOverrides,
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
  List<riverpod.Override> extraOverrides = const [],
}) {
  return _scopeWithOverrides(
    discoveryState: discoveryState,
    downloadState: downloadState,
    extraOverrides: extraOverrides,
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
        find.text(
          "This device is not in our library. We'll try to connect, "
          'but download may not work.',
        ),
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

    // -----------------------------------------------------------------------
    // Capturing downloaded dives (_captureAndAdvance): the completion listener
    // and the import-partial action both funnel here.
    // -----------------------------------------------------------------------

    testWidgets('a completed download captures dives and advances the wizard', (
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
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      expect(container.read(dcAdapterDownloadCanAdvanceProvider), isFalse);

      // Transition the download to complete with dives: the step's listener
      // fires _captureAndAdvance, which (via a post-frame callback) flips the
      // can-advance provider so the wizard can move to Review.
      container.read(downloadNotifierProvider.notifier).state = DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [_downloadedDive(), _downloadedDive()],
      );
      await tester.pumpAndSettle();

      expect(container.read(dcAdapterDownloadCanAdvanceProvider), isTrue);
    });

    testWidgets('a completed download with no dives shows the no-dives view', (
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
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      container
          .read(downloadNotifierProvider.notifier)
          .state = const DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [],
      );
      await tester.pumpAndSettle();

      expect(find.byType(DcNoNewDivesView), findsOneWidget);
      expect(container.read(dcAdapterDownloadCanAdvanceProvider), isFalse);
    });

    // Issue #865: a first-time pairing whose download happened to find nothing
    // new used to return before ensureComputer(), so a dive computer that had
    // just proved it pairs, connects and downloads was never saved -- the diver
    // had to rediscover it every time.
    testWidgets(
      'a completed download with no dives still saves the dive computer',
      (tester) async {
        final repository = _RecordingDiveComputerRepository();
        final adapter = _makeAdapter(computerRepository: repository);

        await tester.pumpWidget(
          _buildDownloadStep(
            adapter: adapter,
            discoveryState: DiscoveryState(selectedDevice: _testDevice),
          ),
        );
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DcAdapterDownloadStep)),
        );
        container
            .read(downloadNotifierProvider.notifier)
            .state = const DownloadState(
          phase: DownloadPhase.complete,
          downloadedDives: [],
          firmwareVersion: '92',
        );
        await tester.pumpAndSettle();

        expect(find.byType(DcNoNewDivesView), findsOneWidget);
        expect(repository.created, hasLength(1));
        expect(repository.created.single.bluetoothAddress, _testDevice.address);
        expect(repository.created.single.firmwareVersion, '92');
        // Still no Review step to advance to -- only the saving changed.
        expect(container.read(dcAdapterDownloadCanAdvanceProvider), isFalse);
      },
    );

    testWidgets('a completed download records what the model answered', (
      tester,
    ) async {
      final repository = _RecordingDiveComputerRepository();
      final adapter = _makeAdapter(computerRepository: repository);

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      container
          .read(downloadNotifierProvider.notifier)
          .state = const DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [],
        clockSyncStatus: ClockSyncStatus.unsupported,
      );
      await tester.pumpAndSettle();

      final savedId = repository.created.single.id;
      expect(
        container.read(clockSyncSettingsNotifierProvider).supportFor(savedId),
        ClockSyncSupport.unsupported,
      );
    });

    testWidgets('a failed clock sync records nothing about the model', (
      tester,
    ) async {
      final repository = _RecordingDiveComputerRepository();
      final adapter = _makeAdapter(computerRepository: repository);

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      container
          .read(downloadNotifierProvider.notifier)
          .state = const DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [],
        clockSyncStatus: ClockSyncStatus.failed,
      );
      await tester.pumpAndSettle();

      final savedId = repository.created.single.id;
      expect(
        container.read(clockSyncSettingsNotifierProvider).supportFor(savedId),
        ClockSyncSupport.unknown,
      );
    });

    // Issue #2439: saving the computer and noting its clock sync answer are
    // bookkeeping, and the dives are already in hand. A failure in either used
    // to escape the post-frame callback before it enabled Next, leaving the
    // wizard on "Download complete" with no way forward.
    testWidgets(
      'a completed download still advances when saving the computer fails',
      (tester) async {
        final adapter = _makeAdapter(
          computerRepository: _FailingCreateDiveComputerRepository(),
        );

        await tester.pumpWidget(
          _buildDownloadStep(
            adapter: adapter,
            discoveryState: DiscoveryState(selectedDevice: _testDevice),
          ),
        );
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DcAdapterDownloadStep)),
        );
        container.read(downloadNotifierProvider.notifier).state = DownloadState(
          phase: DownloadPhase.complete,
          downloadedDives: [_downloadedDive(), _downloadedDive()],
          serialNumber: '12345',
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(container.read(dcAdapterDownloadCanAdvanceProvider), isTrue);
      },
    );

    testWidgets(
      'a completed download still advances when recording clock sync fails',
      (tester) async {
        final repository = _RecordingDiveComputerRepository();
        final adapter = _makeAdapter(computerRepository: repository);

        await tester.pumpWidget(
          _buildDownloadStep(
            adapter: adapter,
            discoveryState: DiscoveryState(selectedDevice: _testDevice),
            extraOverrides: [
              clockSyncSettingsNotifierProvider.overrideWith(
                (ref) => _FailingClockSyncSettingsNotifier(),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DcAdapterDownloadStep)),
        );
        container.read(downloadNotifierProvider.notifier).state = DownloadState(
          phase: DownloadPhase.complete,
          downloadedDives: [_downloadedDive()],
          clockSyncStatus: ClockSyncStatus.unsupported,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(repository.created, hasLength(1));
        expect(container.read(dcAdapterDownloadCanAdvanceProvider), isTrue);
      },
    );

    // The clock sync answer needs a computer id. When the first save fails
    // the step has nothing to record it against, so the adapter carries it
    // and records it once buildBundle's retry recovers the computer.
    testWidgets('records the clock sync answer once a retried save recovers', (
      tester,
    ) async {
      final created = _makeComputer(id: 'recovered-computer');
      var attempts = 0;
      final repository = _FlakyCreateDiveComputerRepository(() {
        attempts++;
        if (attempts == 1) throw StateError('database is locked');
        return created;
      });
      DiveComputerAdapter? adapter;

      await tester.pumpWidget(
        _scopeWithOverrides(
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  adapter ??= _makeAdapter(
                    computerRepository: repository,
                    ref: ref,
                  );
                  return DcAdapterDownloadStep(adapter: adapter!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      container.read(downloadNotifierProvider.notifier).state = DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [_downloadedDive()],
        clockSyncStatus: ClockSyncStatus.unsupported,
      );
      await tester.pumpAndSettle();
      expect(adapter!.computer, isNull);

      await adapter!.buildBundle();

      expect(adapter!.computer, equals(created));
      expect(
        container
            .read(clockSyncSettingsNotifierProvider)
            .supportFor('recovered-computer'),
        ClockSyncSupport.unsupported,
      );
    });

    testWidgets(
      'importing a partial download captures dives and advances the wizard',
      (tester) async {
        final computer = _makeComputer();
        final adapter = _makeAdapter(knownComputer: computer);

        await tester.pumpWidget(
          _buildDownloadStep(
            adapter: adapter,
            knownComputer: computer,
            discoveryState: DiscoveryState(selectedDevice: _testDevice),
          ),
        );
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DcAdapterDownloadStep)),
        );

        // An interrupted download that already delivered dives: the download
        // widget offers an import-partial action wired to _captureAndAdvance.
        container.read(downloadNotifierProvider.notifier).state = DownloadState(
          phase: DownloadPhase.error,
          errorMessage: 'Connection timed out',
          downloadedDives: [_downloadedDive(), _downloadedDive()],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import 2 downloaded dives'));
        await tester.pumpAndSettle();

        expect(container.read(dcAdapterDownloadCanAdvanceProvider), isTrue);
      },
    );
  });
}

DownloadedDive _downloadedDive() => DownloadedDive(
  startTime: DateTime(2026, 3, 15, 10, 0),
  durationSeconds: 40 * 60,
  maxDepth: 20.0,
  profile: const [],
  tanks: const [],
);
