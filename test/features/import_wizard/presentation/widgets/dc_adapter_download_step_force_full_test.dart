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
        diverId: 'diver-1',
      );

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          deps: deps,
          knownComputer: computer,
        ),
      );
      await tester.pump();

      final step = tester.widget<DownloadStepWidget>(
        find.byType(DownloadStepWidget),
      );
      expect(step.forceFullDownload, isFalse);
    },
  );
}
