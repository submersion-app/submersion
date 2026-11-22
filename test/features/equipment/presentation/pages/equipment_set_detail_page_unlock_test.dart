import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_set_detail_page_unlock_harness.dart';

/// The equipment set page edits in place behind the phase 3 switch (issue
/// #4527): it opens locked, a sitting holds its cards, and one Save writes
/// it as one History entry.
void main() {
  final l = AppLocalizationsEn();

  final header = l.settings_conflict_ref_equipmentSet;
  final figure = l.equipment_setEdit_figureSwitch_title;
  final members = l.equipment_setDetail_equipmentInSetTitle;
  final bundle = l.equipment_setEdit_bundleTitle;
  final geofences = l.equipment_setDetail_geofencesTitle;

  setUp(seedSetPage);
  tearDown(tearDownTestDatabase);

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    final pencil = find.byTooltip(l.recordEdit_editCardTooltip(title));
    await tester.ensureVisible(pencil);
    await tester.pumpAndSettle();
    await tester.tap(pencil);
    await tester.pumpAndSettle();
  }

  Future<void> closeCards(WidgetTester tester) async {
    while (find.text(l.common_action_done).evaluate().isNotEmpty) {
      await tester.tap(find.text(l.common_action_done).first);
      await tester.pumpAndSettle();
    }
  }

  Finder saveButton() => find.widgetWithText(AppBarTextAction, l.forms_save);

  /// Taps Save and lets its write, on the real database, finish.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  /// The checkbox row of [name] in the open Members editor, its type's
  /// group opened first when folded.
  Future<void> tick(WidgetTester tester, String name, String type) async {
    final row = find.widgetWithText(CheckboxListTile, name);
    if (row.evaluate().isEmpty) {
      await tester.tap(find.text(type).last);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  Finder inStrip(String title) =>
      find.descendant(of: find.byType(AddStrip), matching: find.text(title));

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpSetPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('a long name fills the header row, with the switch on or off', (
    tester,
  ) async {
    const long = 'Cold water expedition rig for the Baltic wrecks in winter';
    await DatabaseService.instance.database.customStatement(
      "UPDATE equipment_sets SET name = '$long' WHERE id = 's1'",
    );
    await pumpSetPage(tester);
    final name = find.descendant(
      of: find.byType(Card).first,
      matching: find.text(long),
    );
    // The avatar and its gap take about 100 of the 600 wide page; the name
    // must have the rest, not half of it.
    expect(tester.getSize(name).width, greaterThan(330));
  });

  testWidgets('default on in a sitting moves the default for the rest of the '
      'app', (tester) async {
    await pumpSetPage(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EquipmentSetDetailPage)),
    );
    final before = await tester.runAsync(
      () => container.read(defaultEquipmentSetProvider.future),
    );
    expect(before?.id, 's2');
    await unlock(tester);
    await openCard(tester, header);
    await tester.tap(find.byKey(const ValueKey('set-edit-default')));
    await tester.pumpAndSettle();

    await save(tester);

    final after = await tester.runAsync(
      () => container.read(defaultEquipmentSetProvider.future),
    );
    expect(after?.id, 's1');
    final s2 = await tester.runAsync(
      () => container.read(equipmentSetProvider('s2').future),
    );
    expect(s2?.isDefault, isFalse);
  });

  testWidgets('locked, no tap writes', (tester) async {
    await pumpSetPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await openMenu(tester);
    final delete = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text(l.equipment_setDetail_deleteMenuItem),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(delete.enabled, isFalse);
    expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Bare drysuit'));
    await tester.pumpAndSettle();
    expect(find.text('item e1'), findsOneWidget);
    expect(await setPageOperations(tester), isEmpty);
    expect((await storedSet(tester)).name, 'Cold water');
  });

  testWidgets('the menu offers Clone while locked', (tester) async {
    await pumpSetPage(tester);
    await openMenu(tester);

    expect(find.text(l.equipment_menu_clone), findsOneWidget);
  });

  testWidgets('name and description in one sitting save as one entry and '
      'lock', (tester) async {
    await pumpSetPage(tester);
    await unlock(tester);
    await openCard(tester, header);
    await tester.enterText(
      find.byKey(const ValueKey('set-edit-name')),
      'Cold water rig',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('set-edit-description')),
        matching: find.byType(TextField),
      ),
      'Kelp forest',
    );
    await tester.pumpAndSettle();

    await save(tester);

    final stored = await storedSet(tester);
    expect(stored.name, 'Cold water rig');
    expect(stored.description, 'Kelp forest');
    expect(await setPageOperations(tester), [
      'record_edit:equipment_sets:s1:header',
    ]);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('default and a geofence in one sitting save as one entry', (
    tester,
  ) async {
    await pumpSetPage(tester);
    await unlock(tester);
    await openCard(tester, header);
    await tester.tap(find.byKey(const ValueKey('set-edit-default')));
    await tester.pumpAndSettle();
    await openCard(tester, geofences);
    await tester.tap(find.byTooltip(l.equipment_setEdit_removeGeofence));
    await tester.pumpAndSettle();

    await save(tester);

    expect((await storedSet(tester)).isDefault, isTrue);
    expect((await storedSet(tester)).geofences, isEmpty);
    expect((await storedSet(tester, 's2')).isDefault, isFalse);
    final ops = await setPageOperations(tester);
    expect(ops, hasLength(1));
    expect(ops.single, contains('header'));
    expect(ops.single, contains('geofences'));
  });

  testWidgets('a blank name cannot be saved', (tester) async {
    await pumpSetPage(tester);
    await unlock(tester);
    await openCard(tester, header);
    await tester.enterText(find.byKey(const ValueKey('set-edit-name')), '   ');
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.equipment_setEdit_nameValidation), findsOneWidget);
    expect(await setPageOperations(tester), isEmpty);
  });

  testWidgets("the Figure editor's switch is held and written at Save", (
    tester,
  ) async {
    await pumpSetPage(tester);
    await unlock(tester);
    final chip = inStrip(figure);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-edit-show-figure')));
    await tester.pumpAndSettle();
    expect((await storedSet(tester)).showFigure, isFalse);

    await save(tester);

    expect((await storedSet(tester)).showFigure, isTrue);
    expect(await setPageOperations(tester), [
      'record_edit:equipment_sets:s1:figure',
    ]);
  });

  testWidgets('a weight preset added in the Bundle editor is written at '
      'Save', (tester) async {
    await pumpSetPage(tester);
    await unlock(tester);
    final chip = inStrip(bundle);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    // A set it can include is offered.
    await tester.tap(find.byKey(const Key('set-bundle-add-includes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-bundle-option-s2')));
    await tester.pumpAndSettle();
    expect((await storedSet(tester)).includedSetIds, isEmpty);

    await save(tester);

    expect((await storedSet(tester)).includedSetIds, ['s2']);
  });

  testWidgets('a weight preset chosen in the Bundle editor is written at '
      'Save', (tester) async {
    final preset = (await tester.runAsync(
      () => WeightPresetRepository().createPreset(
        diverId: 'd1',
        displayName: 'Cold 8 kg',
        entries: const [],
      ),
    ))!;
    await pumpSetPage(tester);
    await unlock(tester);
    final chip = inStrip(bundle);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-bundle-add-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('set-bundle-option-${preset.id}')));
    await tester.pumpAndSettle();
    expect((await storedSet(tester)).weightPresetIds, isEmpty);

    await save(tester);

    expect((await storedSet(tester)).weightPresetIds, [preset.id]);
  });

  testWidgets('auto-apply on shows its row in the header', (tester) async {
    await DatabaseService.instance.database.customStatement(
      "UPDATE equipment_sets SET auto_apply_on_computer_import = 1 "
      "WHERE id = 's1'",
    );
    await pumpSetPage(tester);

    expect(
      find.text(l.equipment_setEdit_computerAutoApplySwitch_title),
      findsOneWidget,
    );
  });

  testWidgets('Figure is offered in the strip while the figure is off, '
      'Bundle while its lists are empty', (tester) async {
    await pumpSetPage(tester);
    await unlock(tester);

    expect(inStrip(figure), findsOneWidget);
    expect(inStrip(bundle), findsOneWidget);
    expect(inStrip(members), findsNothing);
    expect(inStrip(geofences), findsNothing);
  });

  testWidgets('Members and Geofences show while empty', (tester) async {
    await pumpSetPage(tester, setId: 's2');
    await unlock(tester);

    expect(find.text(members), findsWidgets);
    expect(find.text(l.equipment_setDetail_emptySet), findsOneWidget);
    expect(find.text(l.equipment_setDetail_noGeofences), findsOneWidget);
    expect(find.byTooltip(l.recordEdit_editCardTooltip(members)), findsOne);
    expect(find.byTooltip(l.recordEdit_editCardTooltip(geofences)), findsOne);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpSetPage(tester);
    await unlock(tester);
    await openCard(tester, header);
    await tester.enterText(find.byKey(const ValueKey('set-edit-name')), 'X');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a name typed and put back leaves Save disabled', (tester) async {
    await pumpSetPage(tester);
    await unlock(tester);
    await openCard(tester, header);
    final name = find.byKey(const ValueKey('set-edit-name'));
    await tester.enterText(name, 'Other');
    await tester.pumpAndSettle();
    await tester.enterText(name, 'Cold water');
    await tester.pumpAndSettle();

    expect(tester.widget<AppBarTextAction>(saveButton()).onPressed, isNull);
  });

  group('hosts and operations', () {
    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpSetPage(tester, openUnlocked: true);

      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets("the sets pane's edit opens the page unlocked, Cancel "
        'returns to view', (tester) async {
      var ended = 0;
      await pumpSetPage(
        tester,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();

      expect(ended, 1);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets("the pane's Save updates the set and returns to view", (
      tester,
    ) async {
      var ended = 0;
      await pumpSetPage(
        tester,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      await openCard(tester, header);
      await tester.enterText(
        find.byKey(const ValueKey('set-edit-name')),
        'Kelp',
      );
      await tester.pumpAndSettle();

      await save(tester);

      expect((await storedSet(tester)).name, 'Kelp');
      expect(ended, 1);
    });

    testWidgets('unlocked and clean, Delete asks and deletes', (tester) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.equipment_setDetail_deleteMenuItem));
      await tester.pumpAndSettle();
      expect(find.text(l.equipment_setDetail_deleteDialog_title), findsOne);

      await tester.tap(find.text(l.equipment_setDetail_deleteDialog_confirm));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('gear list'), findsOneWidget);
      final gone = await tester.runAsync(
        () => EquipmentSetRepository().getSetById('s1'),
      );
      expect(gone, isNull);
    });

    testWidgets('with unsaved changes Delete waits for Save or Cancel', (
      tester,
    ) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openCard(tester, header);
      await tester.enterText(find.byKey(const ValueKey('set-edit-name')), 'X');
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text(l.recordEdit_saveOrCancelFirst), findsOneWidget);
    });

    testWidgets('Clone works locked and opens the form', (tester) async {
      await pumpSetPage(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.equipment_menu_clone));
      await tester.pumpAndSettle();

      expect(find.text('new set s1'), findsOneWidget);
    });
  });

  group('members follow the sitting', () {
    setUp(() async {
      await tearDownTestDatabase();
      await seedSetPage(showFigure: true);
    });

    GearFigure? figureShown(WidgetTester tester) {
      final found = find.byType(GearFigure);
      return found.evaluate().isEmpty ? null : tester.widget(found);
    }

    testWidgets('ticking a member redraws the Figure card and the count', (
      tester,
    ) async {
      await pumpSetPage(tester);
      expect(figureShown(tester)!.model.itemCount, 2);
      await unlock(tester);
      await openCard(tester, members);

      await tick(tester, 'Jet fins', 'Fins');

      expect(figureShown(tester)!.model.itemCount, 3);
      expect(find.text(l.equipment_sets_itemCountPlural(3)), findsWidgets);
      expect((await storedSet(tester)).equipmentIds, hasLength(2));
    });

    testWidgets('the closed Members card lists the held members with its '
        'dot', (tester) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openCard(tester, members);
      await tick(tester, 'Jet fins', 'Fins');

      await closeCards(tester);

      expect(find.widgetWithText(ListTile, 'Jet fins'), findsOneWidget);
      expect(find.byType(RecordChangedDot), findsWidgets);

      await save(tester);
      expect(
        (await storedSet(tester)).equipmentIds,
        unorderedEquals(['e1', 'e2', 'e3']),
      );
      expect(await setPageOperations(tester), [
        'record_edit:equipment_sets:s1:members',
      ]);
    });

    testWidgets("the Figure card's title follows the held name", (
      tester,
    ) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openCard(tester, header);
      await tester.enterText(
        find.byKey(const ValueKey('set-edit-name')),
        'Cold water rig',
      );
      await tester.pumpAndSettle();

      expect(figureShown(tester)!.title, 'Cold water rig');
    });

    testWidgets('while the held name is blank the figure keeps the stored '
        'name', (tester) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openCard(tester, header);
      await tester.enterText(find.byKey(const ValueKey('set-edit-name')), '');
      await tester.pumpAndSettle();

      expect(figureShown(tester)!.title, 'Cold water');
    });

    // The figure is drawn on the closed card; the open one is its editor.
    testWidgets("the Figure editor's switch hides and shows the figure", (
      tester,
    ) async {
      await pumpSetPage(tester);
      await unlock(tester);
      final toggle = find.byKey(const ValueKey('set-edit-show-figure'));

      await openCard(tester, figure);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await closeCards(tester);
      expect(figureShown(tester), isNull);

      final chip = inStrip(figure);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await closeCards(tester);
      expect(figureShown(tester), isNotNull);
    });

    testWidgets('untick every member and the Figure card goes', (tester) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openCard(tester, members);
      await tick(tester, 'Bare drysuit', 'Drysuit');
      await tick(tester, 'Apeks reg', 'Regulator');

      expect(figureShown(tester), isNull);
    });

    testWidgets('a member row opens the gear item, and the sitting stays '
        'open on return', (tester) async {
      await pumpSetPage(tester);
      await unlock(tester);
      await openCard(tester, header);
      await tester.enterText(find.byKey(const ValueKey('set-edit-name')), 'X');
      await tester.pumpAndSettle();
      await closeCards(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Bare drysuit'));
      await tester.pumpAndSettle();
      expect(find.text('item e1'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text('X'), findsWidgets);
    });
  });
}
