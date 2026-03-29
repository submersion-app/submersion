import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart'
    show DownloadEvent;

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake service -- avoids platform channels entirely
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
// Fake DiveComputerRepository -- avoids database access
// ---------------------------------------------------------------------------

class _FakeDiveComputerRepository extends DiveComputerRepository {
  @override
  Future<void> updateComputer(dynamic computer) async {}
}

// ---------------------------------------------------------------------------
// Stubbed notifier that preserves seeded state
// ---------------------------------------------------------------------------

/// A [DownloadNotifier] subclass whose [reset] and [startDownload] are no-ops.
///
/// The widget's initState triggers reset() then startDownload(). In tests we
/// want to seed a particular [DownloadState] and verify the resulting UI
/// without the real download lifecycle overwriting it.
class _StubbedDownloadNotifier extends DownloadNotifier {
  _StubbedDownloadNotifier()
    : super(
        service: _FakeDiveComputerService(),
        repository: _FakeDiveComputerRepository(),
      );

  @override
  void reset() {
    // no-op: preserve seeded state
  }

  @override
  Future<void> startDownload(
    DiscoveredDevice device, {
    DiveComputer? computer,
  }) async {
    // no-op: avoid real download
  }

  @override
  Future<void> cancelDownload() async {
    state = state.copyWith(phase: DownloadPhase.cancelled);
  }
}

// ---------------------------------------------------------------------------
// Test device
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the test widget wrapped in ProviderScope with a
/// [_StubbedDownloadNotifier] seeded to [initialState].
Widget _buildWidget({
  DiscoveredDevice? device,
  DownloadState initialState = const DownloadState(),
  VoidCallback? onComplete,
  void Function(String)? onError,
}) {
  return ProviderScope(
    overrides: [
      diveComputerServiceProvider.overrideWithValue(_FakeDiveComputerService()),
      diveComputerRepositoryProvider.overrideWithValue(
        _FakeDiveComputerRepository(),
      ),
      downloadNotifierProvider.overrideWith((ref) {
        final notifier = _StubbedDownloadNotifier();
        notifier.state = initialState;
        return notifier;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DownloadStepWidget(
          device: device ?? _testDevice,
          onComplete: onComplete ?? () {},
          onError: onError ?? (_) {},
        ),
      ),
    ),
  );
}

DownloadedDive _makeDive({
  int? diveNumber,
  DateTime? startTime,
  int durationSeconds = 47 * 60,
  double maxDepth = 32.4,
  double? avgDepth = 18.0,
  double? minTemperature = 22.0,
  List<DownloadedTank> tanks = const [],
  String? decoAlgorithm,
  int? gfLow,
  int? gfHigh,
}) {
  return DownloadedDive(
    diveNumber: diveNumber,
    startTime: startTime ?? DateTime(2026, 3, 15, 10, 0),
    durationSeconds: durationSeconds,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    minTemperature: minTemperature,
    profile: const [],
    tanks: tanks,
    decoAlgorithm: decoAlgorithm,
    gfLow: gfLow,
    gfHigh: gfHigh,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DownloadStepWidget', () {
    // -----------------------------------------------------------------------
    // Initializing / preparing state
    // -----------------------------------------------------------------------

    testWidgets('shows preparing text in initializing state', (tester) async {
      await tester.pumpWidget(
        _buildWidget(initialState: const DownloadState()),
      );
      // Use pump() -- pumpAndSettle never finishes due to the indeterminate
      // CircularProgressIndicator animation.
      await tester.pump();
      await tester.pump();

      // The default status text for initializing phase is "Preparing..."
      expect(find.text('Preparing...'), findsOneWidget);
    });

    testWidgets('shows circular progress indicator in initializing state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(initialState: const DownloadState()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Connecting state
    // -----------------------------------------------------------------------

    testWidgets('shows connecting status text', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.connecting,
            progress: DownloadProgress.connecting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connecting to device...'), findsOneWidget);
    });

    testWidgets('shows cancel button during connecting phase', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.connecting,
            progress: DownloadProgress.connecting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Downloading state
    // -----------------------------------------------------------------------

    testWidgets('shows downloading status and progress percentage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(50, 100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Downloading dives...'), findsOneWidget);
      // 50/100 = 50%
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows cancel button during download', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(10, 100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('does not show progress percent when totalDives is 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(0, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With total == 0, showPercent is false so no percentage text.
      expect(find.text('0%'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Complete state
    // -----------------------------------------------------------------------

    testWidgets('shows check icon in complete state', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('does not show cancel button in complete state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows downloaded dives list when dives are present', (
      tester,
    ) async {
      final dives = [
        _makeDive(diveNumber: 1, startTime: DateTime(2026, 3, 15, 10, 0)),
        _makeDive(diveNumber: 2, startTime: DateTime(2026, 3, 15, 14, 30)),
      ];

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(2),
            downloadedDives: dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The dives list header
      expect(find.text('Downloaded Dives'), findsOneWidget);
      // Dive count badge
      expect(find.text('2'), findsOneWidget);
      // Dive numbers
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('shows dive details: depth and duration', (tester) async {
      final dives = [
        _makeDive(
          diveNumber: 1,
          maxDepth: 25.5,
          durationSeconds: 45 * 60,
          avgDepth: 15.3,
          minTemperature: 20.0,
        ),
      ];

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(1),
            downloadedDives: dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('25.5m'), findsOneWidget);
      expect(find.text('45min'), findsOneWidget);
      expect(find.text('avg 15.3m'), findsOneWidget);
      expect(find.text('20C'), findsOneWidget);
    });

    testWidgets('shows deco algorithm and gradient factors', (tester) async {
      final dives = [
        _makeDive(
          diveNumber: 1,
          decoAlgorithm: 'buhlmann',
          gfLow: 40,
          gfHigh: 85,
        ),
      ];

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(1),
            downloadedDives: dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('buhlmann'), findsOneWidget);
      expect(find.text('GF 40/85'), findsOneWidget);
    });

    testWidgets('shows EAN gas mix for non-air tanks', (tester) async {
      final dives = [
        _makeDive(
          diveNumber: 1,
          tanks: const [DownloadedTank(index: 0, o2Percent: 32.0)],
        ),
      ];

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(1),
            downloadedDives: dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EAN32'), findsOneWidget);
    });

    testWidgets('does not show gas mix chip for air tanks', (tester) async {
      final dives = [
        _makeDive(
          diveNumber: 1,
          tanks: const [DownloadedTank(index: 0, o2Percent: 21.0)],
        ),
      ];

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(1),
            downloadedDives: dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Air (21%) is filtered out by the gasMixes logic
      expect(find.text('EAN21'), findsNothing);
    });

    testWidgets('calls onComplete when phase transitions to complete', (
      tester,
    ) async {
      var completeCalled = false;

      // Start in downloading state -- DownloadStepWidget._startDownload will
      // execute, but the fake service is a no-op so the state comes from
      // the initial override. We then manually transition to complete below.
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(50, 100),
          ),
          onComplete: () => completeCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      // Grab the container and update state to complete.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DownloadStepWidget)),
      );
      container.read(downloadNotifierProvider.notifier).state = DownloadState(
        phase: DownloadPhase.complete,
        progress: DownloadProgress.complete(1),
      );

      // Allow the post-frame callback to fire.
      await tester.pumpAndSettle();

      expect(completeCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // Error state
    // -----------------------------------------------------------------------

    testWidgets('shows error icon and message in error state', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(
            phase: DownloadPhase.error,
            errorMessage: 'Connection timed out',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Connection timed out'), findsOneWidget);
    });

    testWidgets('shows retry button in error state', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(
            phase: DownloadPhase.error,
            errorMessage: 'Some error',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('does not show cancel button in error state', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(
            phase: DownloadPhase.error,
            errorMessage: 'Error',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows fallback error text when errorMessage is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(phase: DownloadPhase.error),
        ),
      );
      await tester.pumpAndSettle();

      // Falls back to localized "An error occurred"
      expect(find.text('An error occurred'), findsOneWidget);
    });

    testWidgets('shows no_serial_ports localized error', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(
            phase: DownloadPhase.error,
            errorCode: 'no_serial_ports',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The localized string for no_serial_ports
      expect(find.textContaining('USB serial ports'), findsOneWidget);
    });

    testWidgets('calls onError when error phase is entered', (tester) async {
      String? errorMessage;

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(10, 100),
          ),
          onError: (error) => errorMessage = error,
        ),
      );
      await tester.pumpAndSettle();

      // Transition to error state.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DownloadStepWidget)),
      );
      container
          .read(downloadNotifierProvider.notifier)
          .state = const DownloadState(
        phase: DownloadPhase.error,
        errorMessage: 'BLE disconnected',
      );

      await tester.pumpAndSettle();

      expect(errorMessage, 'BLE disconnected');
    });

    // -----------------------------------------------------------------------
    // Cancelled state
    // -----------------------------------------------------------------------

    testWidgets('shows cancelled text and retry button', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(phase: DownloadPhase.cancelled),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download cancelled'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('does not show cancel button in cancelled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: const DownloadState(phase: DownloadPhase.cancelled),
        ),
      );
      await tester.pumpAndSettle();

      // The "Cancel" button is only shown when isDownloading is true.
      expect(find.text('Cancel'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Processing state
    // -----------------------------------------------------------------------

    testWidgets('shows importing text during processing phase', (tester) async {
      final dives = [_makeDive(), _makeDive()];

      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.processing,
            downloadedDives: dives,
          ),
        ),
      );
      // Processing phase has an indeterminate progress indicator.
      await tester.pump();
      await tester.pump();

      expect(find.text('Importing 2 dives...'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Null device
    // -----------------------------------------------------------------------

    testWidgets('does not crash when device is null', (tester) async {
      await tester.pumpWidget(
        _buildWidget(device: null, initialState: const DownloadState()),
      );
      // Null device means _startDownload is a no-op and the indeterminate
      // progress indicator keeps animating, so use pump().
      await tester.pump();
      await tester.pump();

      // Should render without error -- just shows preparing state.
      expect(find.text('Preparing...'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Phase icons
    // -----------------------------------------------------------------------

    testWidgets('shows bluetooth icon during connecting phase', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.connecting,
            progress: DownloadProgress.connecting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bluetooth_connected), findsOneWidget);
    });

    testWidgets('shows download icon during downloading phase', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(10, 100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download), findsOneWidget);
    });
  });
}
