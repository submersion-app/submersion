import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_findings_card.dart';
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

  group('the page on the host', () {
    testWidgets('with the switch off there is no lock and the page is as '
        'before', (tester) async {
      await pumpGearPage(tester, unlockEditing: false);

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byType(RecordCardFade<EquipmentItem>), findsWidgets);
      final components = tester.widget<ComponentsCard>(
        find.byType(ComponentsCard),
      );
      expect(components.readOnly, isFalse);
    });

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

    testWidgets('with the switch on, Components and Condition findings offer '
        'no action', (tester) async {
      await pumpGearPage(tester);

      expect(
        tester.widget<ComponentsCard>(find.byType(ComponentsCard)).readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<ConditionFindingsCard>(find.byType(ConditionFindingsCard))
            .readOnly,
        isTrue,
      );
      await unlock(tester);
      expect(find.text(l.equipment_components_add), findsNothing);
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

    testWidgets('with the switch off the chip still buys in one tap', (
      tester,
    ) async {
      await pumpGearPage(tester, item: wanted, unlockEditing: false);

      expect(find.text(l.equipment_detail_markPurchased), findsOneWidget);
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
}
