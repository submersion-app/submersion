import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The set form warns before Back throws away unsaved changes, in every
/// mode, as the equipment form does (issue #2156).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> openForm(WidgetTester tester, {String? setId}) async {
    final overrides = await getBaseOverrides();
    overrides.addAll([
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      activeEquipmentProvider.overrideWith(
        (ref) async => const <EquipmentItem>[],
      ),
    ]);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/home/form'),
              child: const Text('OPEN_FORM'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'form',
              builder: (_, _) => EquipmentSetEditPage(setId: setId),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_FORM'));
    await tester.pumpAndSettle();
  }

  Future<void> createSet() => EquipmentSetRepository().createSet(
    EquipmentSet(
      id: 's1',
      diverId: 'd1',
      name: 'Cold Water',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  Finder defaultSwitch() => find.widgetWithText(SwitchListTile, 'Default set');

  group('new set', () {
    testWidgets('Back with nothing entered leaves without asking', (
      tester,
    ) async {
      await openForm(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsNothing);
      expect(find.text('OPEN_FORM'), findsOneWidget);
    });

    testWidgets('Back after typing a name asks first', (tester) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Reef');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.text('Reef'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.text('OPEN_FORM'), findsOneWidget);
      expect(await EquipmentSetRepository().getAllSets(diverId: 'd1'), isEmpty);
    });

    testWidgets('a saved form leaves without asking', (tester) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Reef');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsNothing);
      expect(find.text('OPEN_FORM'), findsOneWidget);
    });
  });

  group('editing a set', () {
    testWidgets('Back with nothing changed leaves without asking', (
      tester,
    ) async {
      await createSet();
      await openForm(tester, setId: 's1');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsNothing);
      expect(find.text('OPEN_FORM'), findsOneWidget);
    });

    testWidgets('Back after a switch is changed asks first', (tester) async {
      await createSet();
      await openForm(tester, setId: 's1');
      await tester.tap(defaultSwitch());
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
    });

    testWidgets('a change put back as it was is no change', (tester) async {
      await createSet();
      await openForm(tester, setId: 's1');
      await tester.tap(defaultSwitch());
      await tester.pump();
      await tester.tap(defaultSwitch());
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsNothing);
      expect(find.text('OPEN_FORM'), findsOneWidget);
    });
  });
}
