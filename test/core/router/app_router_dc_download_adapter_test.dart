import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart'
    as download;
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/fake_import_adapter_deps.dart';
import '../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// The saved-computer download route (/dive-computers/:id/download) watches
// diveComputerByIdProvider, which re-emits on every dive_computers table
// tick. The download itself writes that table when it completes (device
// serial and firmware are persisted), so the route rebuilds in the middle
// of the wizard. The DiveComputerAdapter holds the downloaded dives; if the
// route constructs a new one on rebuild, the wizard's Review step ends up
// with an empty bundle ("Dives (0)" after a two-dive download).
// ---------------------------------------------------------------------------

GoRoute? _findRouteByName(List<RouteBase> routes, String name) {
  for (final route in routes) {
    if (route is GoRoute && route.name == name) return route;
    if (route is GoRoute) {
      final found = _findRouteByName(route.routes, name);
      if (found != null) return found;
    }
    if (route is ShellRoute) {
      final found = _findRouteByName(route.routes, name);
      if (found != null) return found;
    }
  }
  return null;
}

DiveComputer _savedComputer() => DiveComputer.create(
  id: 'dc-1',
  name: 'Tern TX',
  diverId: 'diver-1',
  manufacturer: 'Shearwater',
  model: 'Tern TX',
).copyWith(bluetoothAddress: 'AA:BB:CC:DD:EE:FF', lastDiveFingerprint: 'ff');

void main() {
  testWidgets(
    'the download route keeps its DiveComputerAdapter when the computer '
    'record re-emits',
    (tester) async {
      final deps = FakeImportAdapterDeps();
      final container = ProviderContainer(
        overrides: [
          hasAnyDiversProvider.overrideWith((ref) async => true),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveComputerByIdProvider.overrideWith(
            (ref, id) async => _savedComputer(),
          ),
          diveComputerServiceProvider.overrideWithValue(deps.fakeService),
          // The route and the by-id provider read one repository provider;
          // the adapter and the download step read another with the same
          // name. Pin both to the fake.
          diveComputerRepositoryProvider.overrideWithValue(deps.computerRepo),
          download.diveComputerRepositoryProvider.overrideWithValue(
            deps.computerRepo,
          ),
          diveRepositoryProvider.overrideWithValue(deps.diveRepo),
          download.diveImportServiceProvider.overrideWithValue(
            deps.importService,
          ),
          diveConsolidationServiceProvider.overrideWithValue(
            deps.consolidationService,
          ),
          deviceDescriptorsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final route = _findRouteByName(
        router.configuration.routes,
        'computerDownload',
      );
      expect(route, isNotNull);

      final state = GoRouterState(
        router.configuration,
        uri: Uri.parse('/dive-computers/dc-1/download'),
        matchedLocation: '/dive-computers/dc-1/download',
        fullPath: '/dive-computers/:computerId/download',
        pathParameters: const {'computerId': 'dc-1'},
        pageKey: const ValueKey('/dive-computers/dc-1/download'),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (context) => route!.builder!(context, state),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final wizard = tester.widget<UnifiedImportWizard>(
        find.byType(UnifiedImportWizard),
      );
      final adapter = wizard.adapter;

      // The completed download persists serial/firmware on the computer
      // record; the by-id provider re-emits on that table tick.
      container.invalidate(diveComputerByIdProvider('dc-1'));
      await tester.pump();
      await tester.pump();

      final rebuilt = tester.widget<UnifiedImportWizard>(
        find.byType(UnifiedImportWizard),
      );
      expect(identical(rebuilt.adapter, adapter), isTrue);

      // The step scans for the saved address before connecting; let that
      // timer expire so nothing is pending when the test ends.
      await tester.pump(
        DcAdapterDownloadStep.knownDeviceScanTimeout +
            const Duration(seconds: 1),
      );
      await tester.pump();
    },
  );
}
