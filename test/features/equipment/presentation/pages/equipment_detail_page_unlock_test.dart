import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/presentation/editing/gear_item_sharing_sitting.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sitting_host.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_detail_page_unlock_harness.dart';

/// The gear item page edits in place behind the phase 3 switch (issue
/// #4527, plan 6): it opens locked, a sitting holds its cards, and one Save
/// writes it.
void main() {
  final l = AppLocalizationsEn();

  // The cards read their rows themselves (the tags, the moves); an empty
  // test database answers them with none.
  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    final pencil = find.byTooltip(l.recordEdit_editCardTooltip(title));
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  EditSession<EquipmentItem> sessionOf(WidgetTester tester) {
    final element = tester.element(
      find.byType(RecordCardFrame<EquipmentItem>).first,
    );
    return RecordEditScope.maybeOf<EquipmentItem>(element)!.session!;
  }

  final notes = l.equipment_detail_notesTitle;

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpGearPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('the pane header has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpGearPage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  group('the page on the host', () {
    testWidgets('locked, no tap writes', (tester) async {
      final harness = await pumpGearPage(
        tester,
        item: apex.copyWith(notes: 'Rinse after use'),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // No card offers its pencil while locked.
      expect(find.byTooltip(l.recordEdit_editCardTooltip(notes)), findsNothing);
      // Components, the one action card this task covers that would
      // otherwise write, offers nothing.
      expect(find.text(l.equipment_components_add), findsNothing);
      expect(harness.save.calls, isEmpty);
    });

    testWidgets('notes and documents in one sitting save as one entry and '
        'lock', (tester) async {
      final harness = await pumpGearPage(
        tester,
        item: apex.copyWith(notes: 'Rinse'),
      );
      await unlock(tester);
      await openCard(tester, notes);
      await tester.enterText(
        find.byType(TextField).last,
        'Rinse after every dive',
      );
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, hasLength(1));
      expect(harness.save.calls.single.after.notes, 'Rinse after every dive');
      expect(harness.save.calls.single.cards, {'notes'});
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('empty Notes is offered in the strip', (tester) async {
      await pumpGearPage(tester);
      await unlock(tester);

      expect(find.byType(AddStrip), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AddStrip), matching: find.text(notes)),
        findsOneWidget,
      );
    });

    // Notes of only spaces are empty, as the card counts them: the strip
    // offers them and the page shows no blank card beside it.
    testWidgets('notes of only spaces are offered in the strip, not shown', (
      tester,
    ) async {
      await pumpGearPage(tester, item: apex.copyWith(notes: '   '));
      await unlock(tester);

      expect(
        find.descendant(of: find.byType(AddStrip), matching: find.text(notes)),
        findsOneWidget,
      );
      // The strip's entry is the only Notes on the page.
      expect(find.text(notes), findsOneWidget);
    });

    testWidgets('the documents card holds a detach until Save', (tester) async {
      await pumpGearPage(tester);
      await unlock(tester);

      final session = sessionOf(tester);
      // Held under the documents card from the sitting's start, so a
      // detach in it is written with the Save, not at once.
      expect(sittingDocumentLinks(session), isNotNull);
    });

    testWidgets('calculated cards fade while unlocked', (tester) async {
      await pumpGearPage(tester);
      await unlock(tester);

      final exposure = find.ancestor(
        of: find.byType(ExposureCard),
        matching: find.byType(RecordCardFade<EquipmentItem>),
      );
      expect(exposure, findsOneWidget);
      expect(
        tester.widget<RecordCardFade<EquipmentItem>>(exposure).reason,
        RecordCardFadeReason.calculated,
      );
    });

    testWidgets('unlocked, Components acts only in its open card', (
      tester,
    ) async {
      await pumpGearPage(tester);
      await unlock(tester);
      expect(find.text(l.equipment_components_add), findsNothing);

      await openCard(tester, l.equipment_components_title);

      expect(find.text(l.equipment_components_add), findsOneWidget);
    });

    testWidgets('Cancel with changes asks first', (tester) async {
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      sessionOf(tester).set(gearNotesField, 'Changed');
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.common_action_cancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(harness.save.calls, isEmpty);
    });

    testWidgets('the bar names the item while unlocked', (tester) async {
      await pumpGearPage(tester, item: apex.copyWith(type: EquipmentType.bcd));
      await unlock(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text(l.recordEdit_editingTitle('Apex')), findsOneWidget);
    });
  });

  group('details', () {
    testWidgets('brand and a spec attribute in one sitting are one entry', (
      tester,
    ) async {
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      await openCard(tester, l.equipment_detail_detailsTitle);
      await tester.enterText(
        find.byKey(const ValueKey('gear-edit-brand')),
        'Scubapro',
      );
      await tester.pumpAndSettle();
      final key =
          EquipmentAttributeCatalog.attributesFor(EquipmentType.regulator)
              .firstWhere(
                (d) =>
                    d.group == AttributeGroup.spec &&
                    d.kind == AttributeKind.number,
              )
              .key;
      sessionOf(tester).set(
        gearAttributeField(key),
        EquipmentAttribute.curated(equipmentId: 'g1', key: key, valueNum: 2),
      );
      await tester.pumpAndSettle();

      await save(tester);

      final call = harness.save.calls.single;
      expect(call.after.brand, 'Scubapro');
      expect(call.after.attrNum(key), 2);
      expect(call.cards, {'details'});
    });

    testWidgets('an owned item\'s sharing is read as the sitting starts, '
        'whether or not the profiles are known yet', (tester) async {
      await pumpGearPage(tester, item: apex.copyWith(diverId: 'd1'));
      await unlock(tester);

      expect(gearItemSharing.loaded(sessionOf(tester)), isNotNull);
    });

    testWidgets('an unreadable price keeps the Save from writing', (
      tester,
    ) async {
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      await openCard(tester, l.equipment_detail_detailsTitle);
      final price = find.byKey(const ValueKey('equipment-purchase-price'));
      await tester.ensureVisible(price);
      await tester.enterText(price, '4x0');
      await tester.pumpAndSettle();
      sessionOf(tester).set(gearNotesField, 'Rinse');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, isEmpty);
    });
  });

  group('the dive computer card', () {
    final perdix = apex.copyWith(name: 'Perdix', type: EquipmentType.computer);
    final computerCard = l.diveComputer_title;

    setUp(() async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('d1', 'D', 0, 0)",
      );
      await EquipmentRepository().createEquipment(perdix);
      await db.customStatement(
        "INSERT INTO dive_computers (id, diver_id, name, equipment_id, "
        "is_favorite, created_at, updated_at) VALUES "
        "('c1', 'd1', 'Perdix', 'g1', 0, 0, 0)",
      );
    });

    Future<bool> storedFavourite() async =>
        (await DiveComputerRepository().getComputerById('c1'))!.isFavorite;

    ClockSyncOverride clockSyncOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(EquipmentDetailPage)),
        ).read(clockSyncSettingsNotifierProvider).overrideFor('c1');

    IconButton favourite(WidgetTester tester) => tester.widget<IconButton>(
      find.byKey(const ValueKey('dive_computer_favourite')).first,
    );

    testWidgets('locked with the switch on, the star writes nothing', (
      tester,
    ) async {
      await pumpGearPage(tester, item: perdix);

      expect(favourite(tester).onPressed, isNull);
      expect(await storedFavourite(), isFalse);
    });

    testWidgets('merge is disabled under "Unlock to use these"', (
      tester,
    ) async {
      await pumpGearPage(tester, item: perdix);

      final merge = tester.widget<IconButton>(
        find.byKey(const ValueKey('dive_computer_merge')),
      );
      expect(merge.onPressed, isNull);
      expect(find.byTooltip(l.recordEdit_unlockToUseThis), findsWidgets);
    });

    testWidgets('unlocked and clean, merge is offered; with a change, it is '
        'not', (tester) async {
      await pumpGearPage(tester, item: perdix);
      await unlock(tester);

      IconButton merge() => tester.widget<IconButton>(
        find.byKey(const ValueKey('dive_computer_merge')),
      );
      expect(merge().onPressed, isNotNull);

      sessionOf(tester).set(gearNotesField, 'Changed');
      await tester.pumpAndSettle();
      expect(merge().onPressed, isNull);
    });

    // An operation the diver gives up on wrote nothing: the sitting carries
    // on, its open card still open, rather than starting afresh.
    testWidgets('a merge given up on leaves the sitting as it was', (
      tester,
    ) async {
      await pumpGearPage(tester, item: perdix);
      await unlock(tester);
      await openCard(tester, computerCard);
      final before = sessionOf(tester);

      await tester.tap(find.byKey(const ValueKey('dive_computer_merge')));
      await tester.pumpAndSettle();
      // The picker's sheet, closed with nothing chosen.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(identical(sessionOf(tester), before), isTrue);
      final controller = RecordEditScope.maybeOf<EquipmentItem>(
        tester.element(find.byType(RecordCardFrame<EquipmentItem>).first),
      )!;
      expect(controller.openCardIds, contains('diveComputer'));
    });

    testWidgets('the favourite set in the open card is written with the Save', (
      tester,
    ) async {
      final harness = await pumpGearPage(tester, item: perdix);
      await unlock(tester);
      await openCard(tester, computerCard);

      await tester.tap(find.byKey(const ValueKey('dive_computer_favourite')));
      await tester.pumpAndSettle();
      expect(await storedFavourite(), isFalse);

      await save(tester);

      expect(harness.save.calls.single.cards, {'diveComputer'});
      expect(await storedFavourite(), isTrue);
    });

    testWidgets('a clock sync choice is written after the commit, and not on '
        'Cancel', (tester) async {
      await pumpGearPage(tester, item: perdix);
      await unlock(tester);
      await openCard(tester, computerCard);
      final always = find.descendant(
        of: find.byKey(const ValueKey('clock_sync_override')),
        matching: find.text(l.diveComputer_clockSync_overrideAlways),
      );
      await tester.ensureVisible(always);
      await tester.tap(always);
      await tester.pumpAndSettle();
      expect(clockSyncOf(tester), ClockSyncOverride.inherit);

      await tester.tap(find.text(l.common_action_cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();
      expect(clockSyncOf(tester), ClockSyncOverride.inherit);

      await unlock(tester);
      await openCard(tester, computerCard);
      await tester.ensureVisible(always);
      await tester.tap(always);
      await tester.pumpAndSettle();
      await save(tester);

      expect(clockSyncOf(tester), ClockSyncOverride.always);
    });

    testWidgets('a failed Save leaves the clock sync choice as it was', (
      tester,
    ) async {
      final harness = await pumpGearPage(tester, item: perdix);
      harness.save.fail = true;
      await unlock(tester);
      await openCard(tester, computerCard);
      final never = find.descendant(
        of: find.byKey(const ValueKey('clock_sync_override')),
        matching: find.text(l.diveComputer_clockSync_overrideNever),
      );
      await tester.ensureVisible(never);
      await tester.tap(never);
      await tester.pumpAndSettle();

      await save(tester);

      expect(clockSyncOf(tester), ClockSyncOverride.inherit);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });

  group('whole-record operations on the cards', () {
    final torch = apex.copyWith(name: 'Torch', type: EquipmentType.light);
    final cell = EquipmentItem(
      id: 'c1',
      name: 'Cell',
      type: EquipmentType.battery,
      parentEquipmentId: 'g1',
      createdAt: DateTime(2026),
    );

    PopupMenuItem<Object?> replaceItem(WidgetTester tester) =>
        tester.widget<PopupMenuItem<Object?>>(
          find.ancestor(
            of: find.text(l.equipmentCondition_children_replace),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
          ),
        );

    Future<void> openPartMenu(WidgetTester tester) async {
      final menu = find.byKey(const ValueKey('child-menu-c1'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
    }

    testWidgets('locked, Replace is disabled under "Unlock to use these"', (
      tester,
    ) async {
      await pumpGearPage(tester, item: torch, children: [cell]);
      await openPartMenu(tester);

      expect(replaceItem(tester).enabled, isFalse);
      expect(find.text(l.recordEdit_unlockToUseThis), findsOneWidget);
    });

    testWidgets('unlocked with unsaved changes, Replace is disabled', (
      tester,
    ) async {
      await pumpGearPage(tester, item: torch, children: [cell]);
      await unlock(tester);
      sessionOf(tester).set(gearNotesField, 'Changed');
      await tester.pumpAndSettle();
      await openPartMenu(tester);

      expect(replaceItem(tester).enabled, isFalse);
      expect(find.text(l.recordEdit_saveOrCancelFirst), findsOneWidget);
    });

    testWidgets('unlocked and clean, Replace asks first', (tester) async {
      await pumpGearPage(tester, item: torch, children: [cell]);
      await unlock(tester);
      await openPartMenu(tester);

      expect(replaceItem(tester).enabled, isTrue);
      await tester.tap(find.text(l.equipmentCondition_children_replace));
      await tester.pumpAndSettle();

      expect(
        find.text(l.equipmentCondition_children_replaceTitle('Cell')),
        findsOneWidget,
      );
    });

    testWidgets('Add part works locked', (tester) async {
      await pumpGearPage(tester, item: torch, children: [cell]);

      final add = find.text(l.equipmentCondition_children_add);
      await tester.ensureVisible(add);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(of: add, matching: find.byType(TextButton)),
      );
      expect(button.onPressed, isNotNull);
    });

    final transmitter = apex.copyWith(
      name: 'Swift',
      type: EquipmentType.transmitter,
    );
    final key = Transmitter(
      id: 't1',
      label: 'Swift',
      volumeL: 11,
      transmitterEquipmentId: 'g1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    TextButton apply(WidgetTester tester) => tester.widget<TextButton>(
      find.byKey(const ValueKey('transmitter_apply')),
    );

    testWidgets('locked, Apply to existing dives is disabled', (tester) async {
      await pumpGearPage(
        tester,
        item: transmitter,
        extraOverrides: [
          transmittersForEquipmentProvider(
            'g1',
          ).overrideWith((ref) async => [key]),
        ],
      );

      expect(apply(tester).onPressed, isNull);
      expect(find.byTooltip(l.recordEdit_unlockToUseThis), findsWidgets);
    });

    testWidgets('unlocked and clean, Apply is offered; with a change, it is '
        'not', (tester) async {
      await pumpGearPage(
        tester,
        item: transmitter,
        extraOverrides: [
          transmittersForEquipmentProvider(
            'g1',
          ).overrideWith((ref) async => [key]),
        ],
      );
      await unlock(tester);
      expect(apply(tester).onPressed, isNotNull);

      sessionOf(tester).set(gearNotesField, 'Changed');
      await tester.pumpAndSettle();
      expect(apply(tester).onPressed, isNull);
    });
  });

  group('hosts and the menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const ValueKey('equipment-detail-overflow')).first,
      );
      await tester.pumpAndSettle();
    }

    PopupMenuItem<String> menuItem(WidgetTester tester, String value) =>
        tester.widget<PopupMenuItem<String>>(
          find.byWidgetPredicate(
            (w) => w is PopupMenuItem<String> && w.value == value,
          ),
        );

    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpGearPage(tester, openUnlocked: true);

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets('the pane\'s edit opens unlocked, and Cancel returns to view', (
      tester,
    ) async {
      var ended = 0;
      await pumpGearPage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      expect(find.text(l.common_action_cancel), findsOneWidget);

      await tester.tap(find.text(l.common_action_cancel));
      await tester.pumpAndSettle();

      expect(ended, 1);
    });

    testWidgets('the pane\'s Save updates the item and returns to view', (
      tester,
    ) async {
      var ended = 0;
      final harness = await pumpGearPage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      sessionOf(tester).set(gearNotesField, 'Rinse');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.after.notes, 'Rinse');
      expect(harness.stored.state!.id, 'g1');
      expect(ended, 1);
    });

    // The list's view, as the form's Save checked it (#3068): the pane's
    // item is stored, as the save made it.
    Future<void> paneSave(WidgetTester tester, EquipmentItem item) async {
      await EquipmentRepository().createEquipment(item);
      await pumpGearPage(
        tester,
        item: item,
        embedded: true,
        openUnlocked: true,
      );
      sessionOf(tester).set(gearNotesField, 'Rinse');
      await tester.pumpAndSettle();
      await save(tester);
    }

    testWidgets('a pane Save that hides the item offers its view', (
      tester,
    ) async {
      await paneSave(
        tester,
        apex.copyWith(status: EquipmentStatus.wanted, isActive: false),
      );

      expect(find.text(l.equipment_edit_snackbar_hiddenByView), findsOneWidget);
    });

    testWidgets('a pane Save the view still shows says nothing', (
      tester,
    ) async {
      await paneSave(tester, apex);

      expect(find.text(l.equipment_edit_snackbar_hiddenByView), findsNothing);
    });

    testWidgets('service reminders are rescheduled only when the service '
        'cards changed', (tester) async {
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      sessionOf(tester).set(gearNotesField, 'Rinse');
      await tester.pumpAndSettle();
      await save(tester);
      expect(harness.serviceRecords.refreshes, 0);

      await unlock(tester);
      sessionOf(
        tester,
      ).set(gearCustomReminderField, (enabled: true, days: const [7]));
      await tester.pumpAndSettle();
      await save(tester);
      expect(harness.serviceRecords.refreshes, 1);
    });

    testWidgets('a full page Save stays on the item', (tester) async {
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      sessionOf(tester).set(gearNotesField, 'Rinse');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, hasLength(1));
      expect(find.byType(EquipmentDetailPage), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('locked, Delete is disabled under "Unlock to use these"', (
      tester,
    ) async {
      await pumpGearPage(tester);
      await openMenu(tester);

      expect(menuItem(tester, 'delete').enabled, isFalse);
      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
    });

    testWidgets('unlocked and clean, Delete asks first', (tester) async {
      await pumpGearPage(tester);
      await unlock(tester);
      await openMenu(tester);

      expect(menuItem(tester, 'delete').enabled, isTrue);
      await tester.tap(find.text(l.equipment_menu_delete));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Clone works locked', (tester) async {
      await pumpGearPage(tester);
      await openMenu(tester);

      expect(menuItem(tester, 'clone').enabled, isTrue);
    });
  });

  group('the header block', () {
    final header = l.settings_conflict_ref_equipment;
    final wanted = apex.copyWith(
      status: EquipmentStatus.wanted,
      isActive: false,
    );

    testWidgets('with the switch on the chip offers no purchase', (
      tester,
    ) async {
      await pumpGearPage(tester, item: wanted);

      expect(find.text(l.equipment_detail_markPurchased), findsNothing);
    });

    testWidgets('Mark purchased, then Cancel: still wanted', (tester) async {
      final harness = await pumpGearPage(tester, item: wanted);
      await unlock(tester);
      await openCard(tester, header);

      await tester.tap(find.byKey(const ValueKey('gear-edit-mark-purchased')));
      await tester.pumpAndSettle();
      expect(sessionOf(tester).working.status, EquipmentStatus.active);

      await tester.tap(find.text(l.common_action_cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(harness.save.calls, isEmpty);
      expect(harness.stored.state!.status, EquipmentStatus.wanted);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('a renamed item saves the name under the header block', (
      tester,
    ) async {
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      await openCard(tester, header);
      await tester.enterText(
        find.byKey(const ValueKey('gear-edit-name')),
        'Apex XTX',
      );
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.after.name, 'Apex XTX');
      expect(harness.save.calls.single.cards, {'header'});
    });
  });

  // Every provider the page shows refreshes itself from its own table, so
  // a Save that invalidated them as well would read each one twice.
  test(
    'after a Save, a provider that follows its table is read once',
    () async {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          observationsForEquipmentProvider('g1').overrideWith((ref) async {
            builds++;
            return const [];
          }),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        observationsForEquipmentProvider('g1'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(observationsForEquipmentProvider('g1').future);

      afterGearItemSave(container, equipmentId: 'g1');
      await container.read(observationsForEquipmentProvider('g1').future);

      expect(builds, 1);
    },
  );
}
