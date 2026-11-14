import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/features/import_wizard/presentation/pages/universal_import_wizard_route.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records Garmin downloads instead of reading a device.
class _RecordingNotifier extends UniversalImportNotifier {
  _RecordingNotifier(super.ref);

  final requests = <GarminImportRequest>[];

  @override
  Future<void> importFromGarminDevice([
    GarminImportRequest request = const GarminImportRequest(),
  ]) async => requests.add(request);
}

/// Issue #4223: the route hands its Garmin request to the wizard's adapter,
/// which starts that download when the wizard opens.
void main() {
  late _RecordingNotifier notifier;

  Future<void> pumpRoute(
    WidgetTester tester, {
    GarminImportRequest? garminImport,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          universalImportNotifierProvider.overrideWith(
            (ref) => notifier = _RecordingNotifier(ref),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UniversalImportWizardRoute(garminImport: garminImport),
        ),
      ),
    );
    await tester.pump();
  }

  Object adapterOf(WidgetTester tester) => tester
      .widget<UnifiedImportWizard>(find.byType(UnifiedImportWizard))
      .adapter;

  testWidgets('a Garmin request reaches the wizard adapter', (tester) async {
    const request = GarminImportRequest(computerId: 'dc-1', readAll: true);
    await pumpRoute(tester, garminImport: request);

    expect(adapterOf(tester), isA<UniversalAdapter>());
    expect(notifier.requests, [request]);
  });

  testWidgets('a plain file import has no Garmin request', (tester) async {
    await pumpRoute(tester);

    expect(adapterOf(tester), isA<UniversalAdapter>());
    expect(notifier.requests, isEmpty);
  });
}
