import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_import_adapter_deps.dart';

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _buildDownloadStep({
  required DiveComputerAdapter adapter,
  required MockImportAdapterDeps deps,
}) {
  return ProviderScope(
    overrides: [
      diveComputerServiceProvider.overrideWithValue(deps.fakeService),
      diveComputerRepositoryProvider.overrideWithValue(deps.computerRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: DcAdapterDownloadStep(adapter: adapter)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'setNewDivesOnly(false) is called when forceFullDownload is true',
    (tester) async {
      final deps = MockImportAdapterDeps();
      final adapter = DiveComputerAdapter(
        importService: deps.importService,
        computerRepository: deps.computerRepo,
        diveRepository: deps.diveRepo,
        diverId: 'diver-1',
        forceFullDownload: true,
      );

      await tester.pumpWidget(_buildDownloadStep(adapter: adapter, deps: deps));

      // Trigger post-frame callbacks.
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );

      expect(
        container.read(downloadNotifierProvider).newDivesOnly,
        isFalse,
        reason: 'forceFullDownload should flip newDivesOnly to false',
      );
    },
  );

  testWidgets(
    'newDivesOnly stays true when forceFullDownload is false (default)',
    (tester) async {
      final deps = MockImportAdapterDeps();
      final adapter = DiveComputerAdapter(
        importService: deps.importService,
        computerRepository: deps.computerRepo,
        diveRepository: deps.diveRepo,
        diverId: 'diver-1',
      );

      await tester.pumpWidget(_buildDownloadStep(adapter: adapter, deps: deps));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );

      expect(container.read(downloadNotifierProvider).newDivesOnly, isTrue);
    },
  );
}
