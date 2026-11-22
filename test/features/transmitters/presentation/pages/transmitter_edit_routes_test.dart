import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_routes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The key editor's addresses under a Transmitter item (issue #4527,
/// phase 4): a key's address opens that key's editor alone, never a new-key
/// editor beneath it, however it is reached.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at, serial_number) VALUES ('tx-gear', 'diver-1', "
      "'Back gas tx', 'transmitter', 1, 1, '804512')",
    );
    await TransmitterRepository().create(
      Transmitter(
        id: 'k1',
        diverId: 'diver-1',
        transmitterSerial: '804512',
        label: 'Back gas tx',
        transmitterEquipmentId: 'tx-gear',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<GoRouter> pump(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final diver = MockCurrentDiverIdNotifier();
    await diver.setCurrentDiver('diver-1');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/equipment/:equipmentId',
          builder: (_, _) => const Scaffold(body: Text('ITEM')),
          routes: transmitterEditRoutes(),
        ),
      ],
      initialLocation: '/equipment/tx-gear',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith((ref) => diver),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
        ].cast(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Iterable<TransmitterEditPage> editors(WidgetTester tester) =>
      tester.widgetList<TransmitterEditPage>(
        find.byType(TransmitterEditPage, skipOffstage: false),
      );

  testWidgets("going to a key's address builds that key's editor alone", (
    tester,
  ) async {
    final router = await pump(tester);
    router.go('/equipment/tx-gear/transmitter/k1');
    await tester.pumpAndSettle();

    expect(editors(tester).map((e) => e.transmitterId), ['k1']);
  });

  testWidgets('the new-key address builds the new-key editor', (tester) async {
    final router = await pump(tester);
    router.go('/equipment/tx-gear/transmitter');
    await tester.pumpAndSettle();

    final built = editors(tester).single;
    expect(built.transmitterId, isNull);
    expect(built.equipmentId, 'tx-gear');
  });
}
