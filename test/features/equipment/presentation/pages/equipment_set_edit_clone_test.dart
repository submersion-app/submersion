import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Clone for equipment sets (issue #2156): the form opens filled in from the
/// source and nothing is written until Save.
void main() {
  final repo = EquipmentSetRepository();

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
    for (final id in ['bcd', 'mask']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
    await repo.createSet(
      EquipmentSet(
        id: 'src',
        diverId: 'd1',
        name: 'Cold Water',
        description: 'Drysuit rig',
        equipmentIds: const ['bcd', 'mask'],
        autoApplyOnComputerImport: true,
        // The figure would name each member a second time.
        showFigure: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.setAsDefault('src', diverId: 'd1');
    await repo.addGeofence(
      EquipmentSetGeofence(
        id: 'fence-1',
        setId: 'src',
        label: 'Breakwater',
        latitude: 36.6,
        longitude: -121.9,
        radiusMeters: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  /// What the clone form popped with, or 'none' until it pops.
  late Object? popped;

  Future<void> openClone(WidgetTester tester, {String from = 'src'}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    popped = 'none';
    final overrides = await getBaseOverrides();
    overrides.add(
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await context.push<String>('/home/clone');
              },
              child: const Text('OPEN_CLONE'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'clone',
              builder: (_, _) => EquipmentSetEditPage(cloneFromId: from),
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
    await tester.tap(find.text('OPEN_CLONE'));
    await tester.pumpAndSettle();
  }

  Finder appBarSave() => find.descendant(
    of: find.byType(AppBar),
    matching: find.widgetWithText(AppBarTextAction, 'Save'),
  );

  bool switchValue(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  testWidgets('opens filled in from the source, named as a copy', (
    tester,
  ) async {
    await openClone(tester);

    expect(find.text('Clone Equipment Set'), findsOneWidget);
    expect(find.text('Cold Water (copy)'), findsOneWidget);
    expect(find.text('Drysuit rig'), findsOneWidget);
    expect(switchValue(tester, 'Default set'), isFalse);
    expect(
      switchValue(tester, "Apply when this set's computer is imported"),
      isFalse,
    );
    expect(switchValue(tester, 'Show diver figure'), isFalse);
    expect(find.text('Breakwater'), findsNothing);
    final ticked = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .where((c) => c.value == true);
    expect(ticked, hasLength(2));
  });

  testWidgets('saving creates a second set and leaves the source as it was', (
    tester,
  ) async {
    await openClone(tester);

    await tester.tap(appBarSave());
    await tester.pumpAndSettle();

    expect(find.text('OPEN_CLONE'), findsOneWidget);
    expect(find.text('Equipment set cloned'), findsOneWidget);
    final sets = await repo.getAllSets(diverId: 'd1');
    expect(sets, hasLength(2));
    final clone = sets.singleWhere((s) => s.id != 'src');
    expect(popped, clone.id, reason: 'the form hands back the new set');
    expect(clone.name, 'Cold Water (copy)');
    expect(clone.description, 'Drysuit rig');
    expect(clone.isDefault, isFalse);
    expect(clone.autoApplyOnComputerImport, isFalse);
    expect(clone.showFigure, isFalse);
    expect(
      await repo.getEquipmentIdsInSet(clone.id),
      unorderedEquals(['bcd', 'mask']),
    );
    expect(await repo.getGeofencesForSet(clone.id), isEmpty);

    final source = await repo.getSetById('src');
    expect(source?.name, 'Cold Water');
    expect(source?.isDefault, isTrue);
    expect(source?.autoApplyOnComputerImport, isTrue);
    expect(await repo.getGeofencesForSet('src'), hasLength(1));
  });

  testWidgets('Back on an untouched clone warns that it is not saved', (
    tester,
  ) async {
    await openClone(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard Changes?'), findsOneWidget);

    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard Changes?'), findsNothing);
    expect(find.text('Clone Equipment Set'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN_CLONE'), findsOneWidget);
    expect(popped, isNull, reason: 'a discarded clone hands back nothing');
    expect(await repo.getAllSets(diverId: 'd1'), hasLength(1));
  });

  testWidgets('a missing source says so', (tester) async {
    await openClone(tester, from: 'gone');
    expect(find.text('Set Not Found'), findsOneWidget);
  });
}
