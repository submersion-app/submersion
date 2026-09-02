import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;

import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_import_adapter_deps.dart';

@GenerateMocks([DiveComputerService])
import 'dc_adapter_download_step_cutoff_race_test.mocks.dart';

// ---------------------------------------------------------------------------
// Regression coverage for the first-sync cutoff prompt race:
//
// firstSyncCutoffDefaultProvider is a FutureProvider backed by a real Drift
// query. The first ref.watch always yields AsyncLoading synchronously, so
// DcAdapterDownloadStep must not construct DownloadStepWidget with a
// transient `firstSyncCutoffDefault: null` while the query is still
// in-flight -- doing so would make DownloadStepWidget's initState
// auto-start the download before the real default (possibly non-null)
// arrives, either crashing on a later rebuild or silently skipping the
// prompt the diver was supposed to see.
// ---------------------------------------------------------------------------

DiveComputer _computerWithAddress() => DiveComputer.create(
  id: 'dc-1',
  name: 'Test Computer',
  diverId: 'diver-1',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
).copyWith(bluetoothAddress: 'AA:BB:CC:DD:EE:FF');

Widget _buildWidget({
  required DiveComputerAdapter adapter,
  required FakeImportAdapterDeps deps,
  required DiveComputerService mockService,
  required DiveComputer knownComputer,
  required Completer<DateTime?> cutoffCompleter,
}) {
  return ProviderScope(
    overrides: [
      diveComputerServiceProvider.overrideWithValue(mockService),
      diveComputerRepositoryProvider.overrideWithValue(deps.computerRepo),
      // Empty descriptor list so DcAdapterDownloadStep synthesizes a
      // DiscoveredDevice from the known computer's bluetoothAddress.
      deviceDescriptorsProvider.overrideWith((ref) async => []),
      // Controlled resolution: lets the test hold the cutoff default in
      // AsyncLoading and then resolve it on demand, simulating the query
      // completing after the widget has already mounted.
      firstSyncCutoffDefaultProvider.overrideWith(
        (ref) => cutoffCompleter.future,
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
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

DiveComputerAdapter _adapter(FakeImportAdapterDeps deps) => DiveComputerAdapter(
  importService: deps.importService,
  computerRepository: deps.computerRepo,
  diveRepository: deps.diveRepo,
  consolidationService: deps.consolidationService,
  diverId: 'diver-1',
);

void main() {
  late MockDiveComputerService mockService;

  setUp(() {
    mockService = MockDiveComputerService();
    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());
    // discoveryNotifierProvider (watched by DcAdapterDownloadStep to check
    // for a selected device) constructs a DiscoveryNotifier that subscribes
    // to this stream immediately.
    when(mockService.discoveryComplete).thenAnswer((_) => const Stream.empty());
    // The step scans for the computer's stored address before connecting
    // (issue #1232). Nothing is ever reported, so each test advances past
    // the scan timeout to reach the synthesized-device fallback.
    when(mockService.discoveredDevices).thenAnswer((_) => const Stream.empty());
    when(mockService.startDiscovery(any)).thenAnswer((_) async {});
    when(mockService.stopDiscovery()).thenAnswer((_) async {});
    when(
      mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).thenAnswer((_) async {});
  });

  final pastScanTimeout =
      DcAdapterDownloadStep.knownDeviceScanTimeout + const Duration(seconds: 1);

  testWidgets(
    'late-arriving cutoff default does not crash and shows the prompt '
    'instead of silently auto-starting',
    (tester) async {
      final deps = FakeImportAdapterDeps();
      final computer = _computerWithAddress(); // no stored fingerprint
      final cutoffCompleter = Completer<DateTime?>();

      await tester.pumpWidget(
        _buildWidget(
          adapter: _adapter(deps),
          deps: deps,
          mockService: mockService,
          knownComputer: computer,
          cutoffCompleter: cutoffCompleter,
        ),
      );
      // Let the saved-address scan time out, then _computerResolved and
      // deviceDescriptorsProvider settle. The cutoff provider is still
      // in-flight at this point.
      await tester.pump();
      await tester.pump(pastScanTimeout);
      await tester.pump();
      await tester.pump();

      expect(find.byType(DownloadStepWidget), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verifyNever(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      );

      // Resolve the cutoff default -- simulates the real Drift query
      // completing after the widget already had a chance to render once.
      cutoffCompleter.complete(DateTime.utc(2026, 6, 12));
      await tester.pump();
      await tester.pump();

      // No crash (a null-check failure above would have already thrown).
      // DownloadStepWidget is now constructed with the settled, non-null
      // default and shows the prompt rather than an already-started
      // download.
      expect(find.byType(DownloadStepWidget), findsOneWidget);
      expect(find.text('Download new dives'), findsOneWidget);
      expect(find.text('Download all dives'), findsOneWidget);
      verifyNever(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      );
    },
  );

  testWidgets('empty log (cutoff resolves to null) still auto-starts and never '
      'hangs on the loading spinner', (tester) async {
    final deps = FakeImportAdapterDeps();
    final computer = _computerWithAddress();
    final cutoffCompleter = Completer<DateTime?>();

    await tester.pumpWidget(
      _buildWidget(
        adapter: _adapter(deps),
        deps: deps,
        mockService: mockService,
        knownComputer: computer,
        cutoffCompleter: cutoffCompleter,
      ),
    );
    await tester.pump();
    await tester.pump(pastScanTimeout);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    cutoffCompleter.complete(null);
    await tester.pump();
    await tester.pump();

    expect(find.byType(DownloadStepWidget), findsOneWidget);
    expect(find.text('Download new dives'), findsNothing);
    verify(
      mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).called(1);
  });
}
