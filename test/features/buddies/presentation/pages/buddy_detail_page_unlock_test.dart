import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certifications_sitting.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_gear_sitting.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import 'buddy_detail_page_unlock_harness.dart';

/// The buddy page edits in place behind the phase 3 switch (issue #4527):
/// it opens locked, a sitting holds its cards, and one Save writes it.
void main() {
  final l = AppLocalizationsEn();

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

  EditSession<Buddy> sessionOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Buddy>(
        tester.element(find.byType(RecordCardFrame<Buddy>).first),
      )!.session!;

  final header = BuddyCardId.header.localizedDisplayName(l);
  final contact = l.buddies_section_contact;

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpBuddyPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('the pane header has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpBuddyPage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('locked, no tap writes', (tester) async {
    final harness = await pumpBuddyPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    // The bar's star only shows the favourite.
    expect(
      find.byTooltip(l.diveLog_detail_tooltip_addToFavorites),
      findsNothing,
    );
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('favourite and phone in one sitting save as one entry', (
    tester,
  ) async {
    final harness = await pumpBuddyPage(tester);
    await unlock(tester);
    await openCard(tester, header);
    await tester.tap(find.byKey(const ValueKey('buddy-edit-favorite')));
    await tester.pumpAndSettle();
    await openCard(tester, contact);
    await tester.enterText(
      find.byKey(const ValueKey('buddy-edit-phone')),
      '777',
    );
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'header', 'contact'});
    expect(harness.save.calls.single.after.isFavorite, isTrue);
    expect(harness.save.calls.single.after.phone, '777');
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a refused link at Save leaves the page unlocked with the '
      'message', (tester) async {
    final harness = await pumpBuddyPage(tester);
    harness.save.throwing = RecordSittingRefusal(
      (l10n) => l10n.buddies_linkedProfile_refusedTaken('Sam'),
    );
    await unlock(tester);
    sessionOf(tester).set(buddyNameField, 'Alexander');
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(
      find.text(l.buddies_linkedProfile_refusedTaken('Sam')),
      findsOneWidget,
    );
  });

  testWidgets('excluded from rankings is set on Statistics', (tester) async {
    final harness = await pumpBuddyPage(tester);
    await unlock(tester);
    await openCard(tester, l.buddies_section_diveStatistics);
    // The figures stay in view under the switch while it is open.
    expect(find.text(l.buddies_stat_divesTogether), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('buddy-edit-rankings')));
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'statistics'});
    expect(harness.save.calls.single.after.excludedFromRankings, isTrue);
  });

  testWidgets('an excluded buddy opens with the switch on, and turning it off '
      'saves', (tester) async {
    final harness = await pumpBuddyPage(
      tester,
      buddy: alex.copyWith(excludedFromRankings: true),
    );
    await unlock(tester);
    await openCard(tester, l.buddies_section_diveStatistics);
    final rankings = find.byKey(const ValueKey('buddy-edit-rankings'));
    expect(tester.widget<SwitchListTile>(rankings).value, isTrue);

    await tester.tap(rankings);
    await tester.pumpAndSettle();
    await save(tester);

    expect(harness.save.calls.single.cards, {'statistics'});
    expect(harness.save.calls.single.after.excludedFromRankings, isFalse);
  });

  testWidgets('empty Contact and Notes are offered in the strip', (
    tester,
  ) async {
    await pumpBuddyPage(
      tester,
      buddy: Buddy(
        id: 'b1',
        name: 'Alex',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    await unlock(tester);

    for (final title in [contact, l.buddies_section_notes]) {
      expect(
        find.descendant(of: find.byType(AddStrip), matching: find.text(title)),
        findsOneWidget,
        reason: title,
      );
    }
  });

  testWidgets('the menu offers no Lend with the switch on', (tester) async {
    await pumpBuddyPage(tester);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text(l.buddies_action_lendGear), findsNothing);
    expect(find.text(l.buddies_action_shareDives), findsOneWidget);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpBuddyPage(tester);
    await unlock(tester);
    sessionOf(tester).set(buddyNotesField, 'Hi');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  group('certifications', () {
    final rescue = Certification(
      id: 'c1',
      buddyId: 'b1',
      name: 'Rescue',
      agency: 'padi',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

    testWidgets('edited in the dialog, Done, then the buddy\'s Cancel writes '
        'nothing', (tester) async {
      final harness = await pumpBuddyPage(tester, certifications: [rescue]);
      await unlock(tester);
      final session = sessionOf(tester);
      // The harness has no database: the list starts from the provider's.
      buddyCertificationsList.loadNone(session);
      buddyCertificationsList.set(session, [rescue]);
      await openCard(tester, l.buddies_section_certifications);
      await tester.tap(find.byKey(const ValueKey('buddy-cert-c1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('cert-edit-card-number')),
        '42',
      );
      await tester.tap(find.byKey(const ValueKey('buddy-cert-dialog-done')));
      await tester.pumpAndSettle();
      expect(buddyCertificationsList.current(session)!.single.cardNumber, '42');

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      // Discard the changes.
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(harness.save.calls, isEmpty);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets('a certification change and a name change are one entry', (
      tester,
    ) async {
      final harness = await pumpBuddyPage(tester);
      harness.save.runHeld = false;
      await unlock(tester);
      final session = sessionOf(tester);
      buddyCertificationsList.loadNone(session);
      buddyCertificationsList.set(session, [rescue]);
      session.set(buddyNameField, 'Alexander');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.cards, {'header', 'certifications'});
    });
  });

  group('gear', () {
    testWidgets('Gear is offered in the strip while the buddy has none', (
      tester,
    ) async {
      await pumpBuddyPage(tester);
      await unlock(tester);

      expect(
        find.descendant(
          of: find.byType(AddStrip),
          matching: find.text(BuddyCardId.gear.localizedDisplayName(l)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lend and a phone change are one entry', (tester) async {
      final harness = await pumpBuddyPage(tester);
      harness.save.runHeld = false;
      await unlock(tester);
      final session = sessionOf(tester);
      holdBuddyLend(
        session,
        HeldLend(
          items: const [
            EquipmentItem(
              id: 'reg',
              name: 'Apeks XTX',
              type: EquipmentType.regulator,
              status: EquipmentStatus.active,
            ),
          ],
          pick: BuddyPick(alex),
          plan: EquipmentMovePlan(
            items: const {'reg': EquipmentStatus.active},
            movedAt: DateTime(2026),
          ),
          diverId: 'd1',
        ),
      );
      session.set(buddyPhoneField, '777');
      await tester.pumpAndSettle();
      // The lent gear shows on the page before Save.
      expect(find.text('Apeks XTX'), findsOneWidget);

      await save(tester);

      expect(harness.save.calls.single.cards, {'contact', 'gear'});
    });
  });

  group('opening and operations', () {
    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpBuddyPage(tester, openUnlocked: true);

      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets("the pane's edit opens the page unlocked, Cancel returns to "
        'view', (tester) async {
      var ended = 0;
      await pumpBuddyPage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      expect(find.text(l.recordEdit_editingTitle('Alex')), findsOneWidget);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();

      expect(ended, 1);
    });

    testWidgets('locked, Delete is disabled under "Unlock to use these"', (
      tester,
    ) async {
      await pumpBuddyPage(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      final delete = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, l.common_action_delete),
      );
      expect(delete.enabled, isFalse);
    });

    testWidgets('Share dives works locked', (tester) async {
      await pumpBuddyPage(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      final share = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, l.buddies_action_shareDives),
      );
      expect(share.enabled, isTrue);
    });

    testWidgets('unlocked and clean, Delete asks', (tester) async {
      await pumpBuddyPage(tester);
      await unlock(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(RecordEditBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.common_action_delete).last);
      await tester.pumpAndSettle();

      expect(find.text(l.buddies_dialog_deleteTitle), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.common_action_cancel),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
