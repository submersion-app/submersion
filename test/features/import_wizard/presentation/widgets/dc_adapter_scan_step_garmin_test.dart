import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/pages/universal_import_wizard_route.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../dive_computer/presentation/widgets/scan_step_test_support.dart';

/// Issue #4223: picking the Garmin entry in the dive computer wizard's scan
/// step opens the Garmin device import instead of a download.
void main() {
  const entryLabel = 'Garmin watch (Descent, Fenix, Epix...)';

  const shearwater = DeviceModel(
    id: 'Shearwater_Petrel_3',
    manufacturer: 'Shearwater',
    model: 'Petrel',
    connectionTypes: [DeviceConnectionType.usb],
    dcModel: 3,
  );

  DiveComputerAdapter makeAdapter() {
    final computerRepository = DiveComputerRepository();
    final diveRepository = DiveRepository();
    return DiveComputerAdapter(
      importService: DiveImportService(repository: computerRepository),
      computerRepository: computerRepository,
      diveRepository: diveRepository,
      consolidationService: DiveConsolidationService(diveRepository),
      diverId: 'diver-1',
    );
  }

  testWidgets('picking the Garmin entry opens the Garmin device import', (
    tester,
  ) async {
    final adapter = makeAdapter();
    Uri? openedImport;
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(
          path: '/scan',
          builder: (context, state) =>
              Scaffold(body: DcAdapterScanStep(adapter: adapter)),
        ),
        GoRoute(
          path: '/transfer/import-wizard',
          builder: (context, state) {
            openedImport = state.uri;
            return const Scaffold(body: Text('Garmin import'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usbDevicesByManufacturerProvider.overrideWith(
            (ref) async => const {
              'Shearwater': [shearwater],
            },
          ),
          discoveryNotifierProvider.overrideWith(
            (ref) => TestDiscoveryNotifier(),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Cable'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(entryLabel));
    await tester.pumpAndSettle();

    expect(find.text('Garmin import'), findsOneWidget);
    expect(
      openedImport?.queryParameters['source'],
      UniversalImportWizardRoute.garminDeviceSource,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
