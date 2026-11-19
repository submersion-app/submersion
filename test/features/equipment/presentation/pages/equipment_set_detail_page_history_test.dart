import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_set_detail_page_unlock_harness.dart';

/// Counts logged dives as the real one does, and fails the replay on them.
class _FailingReplay extends Fake implements DiveRepository {
  @override
  Future<int> countLoggedDivesWithAnySet(Iterable<String> setIds) async => 1;

  @override
  Future<List<String>> rewriteSetOnDives(
    String setId,
    List<SetHistoryRewrite> rewrites, {
    required bool alsoLogged,
    bool notify = true,
  }) async => throw StateError('replay failed');
}

/// Reads every set but the edited one, then fails to read them all: the
/// sets the question needs cannot be read.
class _FailingAllSets extends EquipmentSetRepository {
  bool fail = false;

  @override
  Future<List<EquipmentSet>> getAllSets({
    String? diverId,
    List<String>? ids,
  }) async {
    if (fail) throw StateError('sets unreadable');
    return super.getAllSets(diverId: diverId, ids: ids);
  }
}

/// A set page's sitting that changes the gear the set applies asks "Update
/// past dives?" at Save (issues #4283, #4527): planned dives follow the set
/// always, logged ones on request, all in the sitting's one History entry.
void main() {
  final l = AppLocalizationsEn();
  final dives = DiveRepository();

  setUp(() async {
    await seedSetPage();
    // s3 includes s1, so its dives carry s1's gear too.
    await EquipmentSetRepository().createSet(
      EquipmentSet(
        id: 's3',
        diverId: 'd1',
        name: 'Expedition',
        includedSetIds: const ['s1'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    for (final (id, planned, viaSet) in [
      ('logged', false, 's1'),
      ('planned', true, 's1'),
      ('outer', false, 's3'),
    ]) {
      await dives.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          diverId: 'd1',
          isPlanned: planned,
        ),
      );
      await dives.replaceGearRows(id, [
        for (final e in ['e1', 'e2'])
          GearProvenance(equipmentId: e, viaSetId: viaSet),
      ]);
    }
    await ChangeLogRepository().settleAll();
    await DatabaseService.instance.database.customStatement(
      'DELETE FROM change_log_operations',
    );
  });
  tearDown(tearDownTestDatabase);

  final question = find.text(l.equipment_components_historyTitle);

  Future<Set<String>> gearOn(WidgetTester tester, String diveId) async =>
      (await tester.runAsync(() async {
        final db = DatabaseService.instance.database;
        return {
          for (final row in await (db.select(
            db.diveEquipment,
          )..where((r) => r.diveId.equals(diveId))).get())
            row.equipmentId,
        };
      }))!;

  Future<Set<String?>> setsOn(WidgetTester tester, String diveId) async =>
      (await tester.runAsync(() async {
        final db = DatabaseService.instance.database;
        return {
          for (final row in await (db.select(
            db.diveEquipment,
          )..where((r) => r.diveId.equals(diveId))).get())
            row.viaSetId,
        };
      }))!;

  /// Unlocks, unticks the regulator in the Members editor and taps Save,
  /// letting the count of logged dives load.
  Future<void> untickRegAndSave(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final pencil = find.byTooltip(
      l.recordEdit_editCardTooltip(l.equipment_setDetail_equipmentInSetTitle),
    );
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await tester.pumpAndSettle();
    final reg = find.widgetWithText(CheckboxListTile, 'Apeks reg');
    await tester.ensureVisible(reg);
    await tester.tap(reg);
    await tester.pumpAndSettle();
    await tapSave(tester);
  }

  testWidgets('Also update rewrites the logged and the planned dive in the '
      'entry', (tester) async {
    await pumpSetPage(tester);
    await untickRegAndSave(tester);
    expect(question, findsOneWidget);
    // Its own logged dive and the one of the set that includes it.
    expect(find.text(l.equipment_components_historyAlsoPast(2)), findsOne);

    await tester.tap(find.text(l.equipment_components_historyAlsoPast(2)));
    await settleSave(tester);

    expect(await gearOn(tester, 'logged'), {'e1'});
    expect(await gearOn(tester, 'outer'), {'e1'});
    expect(await gearOn(tester, 'planned'), {'e1'});
    expect(await setPageOperations(tester), [
      'record_edit:equipment_sets:s1:members',
    ]);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('From now on unlinks the logged dive and rewrites the planned '
      'one', (tester) async {
    await pumpSetPage(tester);
    await untickRegAndSave(tester);

    await tester.tap(find.text(l.equipment_components_historyFutureOnly));
    await settleSave(tester);

    expect(await gearOn(tester, 'logged'), {'e1', 'e2'});
    expect(await setsOn(tester, 'logged'), {null});
    expect(await setsOn(tester, 'outer'), {null});
    expect(await gearOn(tester, 'planned'), {'e1'});
    expect(await setPageOperations(tester), hasLength(1));
  });

  testWidgets('Cancel in the question saves nothing and keeps the sitting', (
    tester,
  ) async {
    await pumpSetPage(tester);
    await untickRegAndSave(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.common_action_cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(
      (await storedSet(tester)).equipmentIds,
      unorderedEquals(['e1', 'e2']),
    );
    expect(await setPageOperations(tester), isEmpty);

    await tapSave(tester);
    expect(question, findsOneWidget, reason: 'a second Save asks again');
  });

  testWidgets('a name change alone asks nothing', (tester) async {
    await pumpSetPage(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(
        l.recordEdit_editCardTooltip(l.settings_conflict_ref_equipmentSet),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('set-edit-name')), 'Kelp');
    await tester.pumpAndSettle();

    await tapSave(tester);
    await settleSave(tester);

    expect(question, findsNothing);
    expect((await storedSet(tester)).name, 'Kelp');
    expect(await gearOn(tester, 'logged'), {'e1', 'e2'});
  });

  testWidgets('no logged dive carries it: nothing is asked and the planned '
      'dive follows', (tester) async {
    await tester.runAsync(
      () => DatabaseService.instance.database.customStatement(
        "DELETE FROM dives WHERE id IN ('logged', 'outer')",
      ),
    );
    await pumpSetPage(tester);
    await untickRegAndSave(tester);
    await settleSave(tester);

    expect(question, findsNothing);
    expect(await gearOn(tester, 'planned'), {'e1'});
    expect((await storedSet(tester)).equipmentIds, ['e1']);
  });

  testWidgets('a set that starts including this one while the question is '
      'open refuses the Save, and the next Save asks again', (tester) async {
    await pumpSetPage(tester);
    await untickRegAndSave(tester);
    expect(find.text(l.equipment_components_historyAlsoPast(2)), findsOne);
    // Another device adds a set that includes s1, with a logged dive.
    await tester.runAsync(() async {
      await EquipmentSetRepository().createSet(
        EquipmentSet(
          id: 's4',
          diverId: 'd1',
          name: 'Liveaboard',
          includedSetIds: const ['s1'],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await dives.createDive(
        domain.Dive(id: 'trip', dateTime: DateTime(2026, 2, 1), diverId: 'd1'),
      );
      await dives.replaceGearRows('trip', const [
        GearProvenance(equipmentId: 'e1', viaSetId: 's4'),
        GearProvenance(equipmentId: 'e2', viaSetId: 's4'),
      ]);
    });

    await tester.tap(find.text(l.equipment_components_historyAlsoPast(2)));
    await settleSave(tester);

    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(await gearOn(tester, 'trip'), {'e1', 'e2'});
    expect(await gearOn(tester, 'logged'), {'e1', 'e2'});
    // The other device's writes are entries of their own; the sitting is
    // none.
    expect(
      await setPageOperations(tester),
      isNot(contains(startsWith('record_edit:'))),
    );

    await tapSave(tester);
    expect(find.text(l.equipment_components_historyAlsoPast(3)), findsOne);
  });

  testWidgets('sets that cannot be read stop the Save, asking nothing', (
    tester,
  ) async {
    final sets = _FailingAllSets();
    await pumpSetPage(
      tester,
      extraOverrides: [equipmentSetRepositoryProvider.overrideWithValue(sets)],
    );
    sets.fail = true;
    await untickRegAndSave(tester);
    await settleSave(tester);

    expect(question, findsNothing);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(await gearOn(tester, 'logged'), {'e1', 'e2'});
    expect(await setPageOperations(tester), isEmpty);
  });

  testWidgets('a rename saves even when the sets cannot be read', (
    tester,
  ) async {
    final sets = _FailingAllSets();
    await pumpSetPage(
      tester,
      extraOverrides: [equipmentSetRepositoryProvider.overrideWithValue(sets)],
    );
    sets.fail = true;
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(
        l.recordEdit_editCardTooltip(l.settings_conflict_ref_equipmentSet),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('set-edit-name')), 'Kelp');
    await tester.pumpAndSettle();

    await tapSave(tester);
    await settleSave(tester);

    expect(find.text(l.recordEdit_saveFailed), findsNothing);
    expect(find.byType(RecordEditBar), findsNothing);
    expect((await storedSet(tester)).name, 'Kelp');
  });

  testWidgets('a failed replay saves nothing and leaves the page unlocked', (
    tester,
  ) async {
    await pumpSetPage(
      tester,
      extraOverrides: [
        diveRepositoryProvider.overrideWithValue(_FailingReplay()),
      ],
    );
    await untickRegAndSave(tester);
    await tester.tap(find.text(l.equipment_components_historyAlsoPast(1)));
    await settleSave(tester);

    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(
      (await storedSet(tester)).equipmentIds,
      unorderedEquals(['e1', 'e2']),
    );
    expect(await setPageOperations(tester), isEmpty);
  });
}

/// Taps Save and waits, outside the fake clock, for the count of logged
/// dives the question needs.
Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

/// Lets a save on the real database finish.
Future<void> settleSave(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}
