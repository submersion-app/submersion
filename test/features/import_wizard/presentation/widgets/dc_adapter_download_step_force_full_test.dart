import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_import_adapter_deps.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiveComputer _computerWithAddress() => DiveComputer.create(
  id: 'dc-1',
  name: 'Test Computer',
  diverId: 'diver-1',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
).copyWith(bluetoothAddress: 'AA:BB:CC:DD:EE:FF');

Widget _buildDownloadStep({
  required DiveComputerAdapter adapter,
  required FakeImportAdapterDeps deps,
  required DiveComputer knownComputer,
}) {
  return ProviderScope(
    overrides: [
      diveComputerServiceProvider.overrideWithValue(deps.fakeService),
      diveComputerRepositoryProvider.overrideWithValue(deps.computerRepo),
      // Return an empty descriptor list so DcAdapterDownloadStep synthesizes
      // a DiscoveredDevice from the known computer's bluetoothAddress.
      deviceDescriptorsProvider.overrideWith((ref) async => []),
      // These tests exercise a computer with no stored fingerprint, so
      // DcAdapterDownloadStep waits on this provider before constructing
      // DownloadStepWidget (see the comment at its call site). Override it
      // rather than hitting the real Drift-backed provider, which has no
      // database in this test and would leave the widget on its loading
      // spinner forever.
      firstSyncCutoffDefaultProvider.overrideWith((ref) async => null),
    ],
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
//
// These tests verify that the adapter's `forceFullDownload` flag is threaded
// through to the DownloadStepWidget's constructor argument. The actual
// reset-then-apply-then-start ordering is verified in
// `test/features/dive_computer/presentation/widgets/download_step_widget_force_full_test.dart`.

final _pastScanTimeout =
    DcAdapterDownloadStep.knownDeviceScanTimeout + const Duration(seconds: 1);

void main() {
  testWidgets(
    'adapter forceFullDownload=true propagates to DownloadStepWidget',
    (tester) async {
      final deps = FakeImportAdapterDeps();
      final computer = _computerWithAddress();
      final adapter = DiveComputerAdapter(
        importService: deps.importService,
        computerRepository: deps.computerRepo,
        diveRepository: deps.diveRepo,
        consolidationService: deps.consolidationService,
        diverId: 'diver-1',
        forceFullDownload: true,
      );

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          deps: deps,
          knownComputer: computer,
        ),
      );
      // The step first scans for the computer's stored address (issue
      // #1232); the fake service never reports a device, so advance past
      // the scan timeout to reach the synthesized-device fallback.
      await tester.pump();
      await tester.pump(_pastScanTimeout);
      // Only one async gate applies here: deviceDescriptorsProvider
      // (synthesizing a device from the known computer). With
      // forceFullDownload=true, `promptCouldApply` in DcAdapterDownloadStep
      // is false, so firstSyncCutoffDefaultProvider is never watched and
      // has no gate to settle. The extra pump is harmless -- it just covers
      // a frame with nothing left to resolve.
      await tester.pump();
      await tester.pump();

      final step = tester.widget<DownloadStepWidget>(
        find.byType(DownloadStepWidget),
      );
      expect(step.forceFullDownload, isTrue);
    },
  );

  testWidgets(
    'adapter forceFullDownload=false (default) propagates to DownloadStepWidget',
    (tester) async {
      final deps = FakeImportAdapterDeps();
      final computer = _computerWithAddress();
      final adapter = DiveComputerAdapter(
        importService: deps.importService,
        computerRepository: deps.computerRepo,
        diveRepository: deps.diveRepo,
        consolidationService: deps.consolidationService,
        diverId: 'diver-1',
      );

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          deps: deps,
          knownComputer: computer,
        ),
      );
      // Advance past the saved-address scan (see the first test).
      await tester.pump();
      await tester.pump(_pastScanTimeout);
      // Two async gates settle in sequence before DownloadStepWidget is
      // constructed: deviceDescriptorsProvider (synthesizing a device from
      // the known computer), then firstSyncCutoffDefaultProvider (only
      // watched when this computer has no stored fingerprint). Each
      // resolution triggers a rebuild on its own frame.
      await tester.pump();
      await tester.pump();

      final step = tester.widget<DownloadStepWidget>(
        find.byType(DownloadStepWidget),
      );
      expect(step.forceFullDownload, isFalse);
    },
  );
}
