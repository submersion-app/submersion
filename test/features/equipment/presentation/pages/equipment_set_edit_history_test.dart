import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Counts one logged dive with the set and fails the replay, as a locked
/// database would.
class _FailingReplay extends Fake implements DiveRepository {
  @override
  Future<int> countLoggedDivesWithSet(String setId) async => 1;

  @override
  Future<List<String>> rewriteSetOnDives(
    String setId,
    List<SetHistoryRewrite> rewrites, {
    required bool alsoLogged,
    bool notify = true,
  }) async => throw StateError('replay failed');
}

/// Saves members as usual but fails to make the set the default, a write
/// that runs after the members are saved.
class _FailingDefault extends EquipmentSetRepository {
  @override
  Future<void> setAsDefault(String id, {String? diverId}) async =>
      throw StateError('default failed');
}

/// Saving a set whose members changed offers to replay the change on the
/// dives that carry the set (issue #4283): the logged ones on request, the
/// planned ones always.
void main() {
  late AppDatabase db;
  final dives = DiveRepository();

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
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
    for (final id in ['wing', 'fins']) {
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
    await EquipmentSetRepository().createSet(
      EquipmentSet(
        id: 's1',
        diverId: 'd1',
        name: 'Warm',
        equipmentIds: const ['wing', 'fins'],
        showFigure: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    // logged is a logged dive, planned a planned one; both carry the set.
    for (final (id, planned) in [('logged', false), ('planned', true)]) {
      await dives.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          diverId: 'd1',
          isPlanned: planned,
        ),
      );
      await dives.replaceGearRows(id, const [
        GearProvenance(equipmentId: 'wing', viaSetId: 's1'),
        GearProvenance(equipmentId: 'fins', viaSetId: 's1'),
      ]);
    }
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> buildPage({
    DiveRepository? diveRepository,
    EquipmentSetRepository? setRepository,
  }) async {
    final overrides = await getBaseOverrides();
    overrides.add(
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
    );
    if (diveRepository != null) {
      overrides.add(diveRepositoryProvider.overrideWithValue(diveRepository));
    }
    if (setRepository != null) {
      overrides.add(
        equipmentSetRepositoryProvider.overrideWithValue(setRepository),
      );
    }
    final router = GoRouter(
      initialLocation: '/home/edit',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => const EquipmentSetEditPage(setId: 's1'),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Finder appBarSave() => find.descendant(
    of: find.byType(AppBar),
    matching: find.widgetWithText(AppBarTextAction, 'Save'),
  );

  Future<Set<String>> gearOn(String diveId) async => {
    for (final row in await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get())
      row.equipmentId,
  };

  Future<Set<String?>> setOn(String diveId) async => {
    for (final row in await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get())
      row.viaSetId,
  };

  /// Opens the editor, unticks fins and saves.
  Future<void> untickFinsAndSave(
    WidgetTester tester, {
    DiveRepository? diveRepository,
    EquipmentSetRepository? setRepository,
    bool makeDefault = false,
  }) async {
    // Tall enough that the whole lazy form is built.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      await buildPage(
        diveRepository: diveRepository,
        setRepository: setRepository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'fins'));
    if (makeDefault) {
      await tester.tap(find.widgetWithText(SwitchListTile, 'Default set'));
    }
    await tester.pump();
    await tester.tap(appBarSave());
    // The save button spins while the question is open, so the frame never
    // settles: pump until the question is on screen instead.
    final question = find.text('Update past dives?');
    for (var i = 0; i < 100 && question.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(question, findsOneWidget, reason: 'saving asks about the dives');
  }

  testWidgets('also update rewrites the logged and the planned dive', (
    tester,
  ) async {
    await untickFinsAndSave(tester);
    expect(find.text('Update past dives?'), findsOneWidget);
    expect(
      find.textContaining('This set is on 1 logged dive.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Also update 1 dive'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(await EquipmentSetRepository().getEquipmentIdsInSet('s1'), ['wing']);
    expect(await gearOn('logged'), {'wing'});
    expect(await gearOn('planned'), {'wing'});
    // Both dives match the set again, so both keep naming it.
    expect(await setOn('logged'), {'s1'});
  });

  testWidgets('from now on saves the set and follows on planned dives', (
    tester,
  ) async {
    await untickFinsAndSave(tester);
    await tester.tap(find.text('From now on'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(await gearOn('logged'), {'wing', 'fins'});
    expect(await gearOn('planned'), {'wing'});
    // The logged dive no longer matches the set, so it stops naming it
    // and keeps its gear as its own (#4500); the planned one still follows.
    expect(await setOn('logged'), {null});
    expect(await setOn('planned'), {'s1'});
  });

  testWidgets('cancel saves nothing and keeps the editor open', (tester) async {
    await untickFinsAndSave(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(EquipmentSetEditPage), findsOneWidget);
    expect(
      await EquipmentSetRepository().getEquipmentIdsInSet('s1'),
      unorderedEquals(['wing', 'fins']),
    );
    expect(await gearOn('planned'), {'wing', 'fins'});
  });

  testWidgets('a failed replay still saves the rest of the edit', (
    tester,
  ) async {
    await untickFinsAndSave(
      tester,
      diveRepository: _FailingReplay(),
      makeDefault: true,
    );
    await tester.tap(find.text('Also update 1 dive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The members and the default flag are saved; the error is shown and
    // the editor stays open.
    expect(find.textContaining('replay failed'), findsOneWidget);
    expect(find.byType(EquipmentSetEditPage), findsOneWidget);
    expect(await EquipmentSetRepository().getEquipmentIdsInSet('s1'), ['wing']);
    expect((await EquipmentSetRepository().getSetById('s1'))!.isDefault, true);
  });

  testWidgets('a failed default save still replays the saved members', (
    tester,
  ) async {
    await untickFinsAndSave(
      tester,
      setRepository: _FailingDefault(),
      makeDefault: true,
    );
    await tester.tap(find.text('From now on'));
    await tester.pumpAndSettle();

    // The default write's error is the one shown, and the planned dive
    // follows the members that were saved before it failed.
    expect(find.textContaining('default failed'), findsOneWidget);
    expect(find.byType(EquipmentSetEditPage), findsOneWidget);
    expect(await EquipmentSetRepository().getEquipmentIdsInSet('s1'), ['wing']);
    expect(await gearOn('planned'), {'wing'});
    expect(await gearOn('logged'), {'wing', 'fins'});
    expect(await setOn('logged'), {null});
  });

  testWidgets('a save that leaves the members alone asks nothing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(await buildPage());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Tropical');
    await tester.tap(appBarSave());
    await tester.pumpAndSettle();

    expect(find.text('Update past dives?'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(await gearOn('logged'), {'wing', 'fins'});
    // Only a change to the members makes a dive stop matching its set.
    expect(await setOn('logged'), {'s1'});
  });
}
