import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_currency_sitting.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'certification_detail_page_unlock_harness.dart';

/// The certification page edits in place behind the phase 3 switch (issue
/// #4527): it opens locked, a sitting holds its cards, and one Save writes
/// it.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip(title)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  final details = l.certifications_detail_sectionTitle_details;

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpCertificationPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('the pane header has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpCertificationPage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('locked, no tap writes', (tester) async {
    final harness = await pumpCertificationPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await tester.tap(find.text('123'));
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('editing the card number and saving writes one sitting and '
      'locks', (tester) async {
    final harness = await pumpCertificationPage(tester);
    await unlock(tester);
    await openCard(tester, details);
    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-card-number')),
      '456',
    );
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'details'});
    expect(harness.save.calls.single.after.cardNumber, '456');
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('456'), findsOneWidget);
  });

  testWidgets('a certification with neither title nor level cannot be saved', (
    tester,
  ) async {
    final harness = await pumpCertificationPage(tester);
    await unlock(tester);
    await openCard(tester, details);
    final element = tester.element(
      find.byType(RecordCardFrame<Certification>).first,
    );
    final session = RecordEditScope.maybeOf<Certification>(element)!.session!;
    session.set(certificationCredentialsField, [
      const CertificationCredential(agency: 'padi'),
    ]);
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, isEmpty);
    expect(
      find.text(l.certifications_edit_validation_certificationOrTitleRequired),
      findsOneWidget,
    );
  });

  testWidgets('a new front photo is a change of Card photos', (tester) async {
    final harness = await pumpCertificationPage(
      tester,
      certification: openWater.copyWith(photoBack: Uint8List.fromList([1])),
    );
    await unlock(tester);
    final element = tester.element(
      find.byType(RecordCardFrame<Certification>).first,
    );
    RecordEditScope.maybeOf<Certification>(
      element,
    )!.session!.set(certificationPhotoFrontField, Uint8List.fromList([2]));
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'cardPhotos'});
    expect(harness.save.calls.single.after.photoFront, [2]);
  });

  testWidgets('empty Instructor, Card photos and Notes are offered in the '
      'strip', (tester) async {
    await pumpCertificationPage(tester);
    await unlock(tester);

    for (final title in [
      l.certifications_detail_sectionTitle_instructor,
      l.certifications_detail_sectionTitle_cardPhotos,
      l.certifications_detail_sectionTitle_notes,
    ]) {
      expect(
        find.descendant(of: find.byType(AddStrip), matching: find.text(title)),
        findsOneWidget,
        reason: title,
      );
    }
  });

  testWidgets('notes added from the strip are saved', (tester) async {
    final harness = await pumpCertificationPage(tester);
    await unlock(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(l.certifications_detail_sectionTitle_notes),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pool sessions');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'notes'});
    expect(harness.save.calls.single.after.notes, 'Pool sessions');
  });

  testWidgets('the documents card holds a detach until Save', (tester) async {
    await pumpCertificationPage(tester);
    await unlock(tester);
    final element = tester.element(
      find.byType(RecordCardFrame<Certification>).first,
    );
    final session = RecordEditScope.maybeOf<Certification>(element)!.session!;

    detachDocument(session, 'doc-1');
    await tester.pumpAndSettle();

    expect(sittingDocumentLinks(session).detach, {'doc-1'});
    expect(session.changedCardIds, contains('documents'));
  });

  testWidgets('currency changes and a card number change are one History '
      'entry', (tester) async {
    final harness = await pumpCertificationPage(tester);
    harness.save.runHeld = false;
    await unlock(tester);
    final element = tester.element(
      find.byType(RecordCardFrame<Certification>).first,
    );
    final session = RecordEditScope.maybeOf<Certification>(element)!.session!;
    // The harness has no database: the list starts empty instead of read.
    certificationEventsList.loadNone(session);
    certificationEventsList.set(session, [
      newCurrencyEvent(
        certificationId: 'c1',
        ruleId: 'padi_reactivate',
        type: CurrencyEventType.refresher,
        date: DateTime(2024),
      ),
    ]);
    session.set(certificationCardNumberField, '456');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'details', 'currency'});
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpCertificationPage(tester);
    await unlock(tester);
    await openCard(tester, details);
    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-card-number')),
      '456',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  group('opening and operations', () {
    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpCertificationPage(tester, openUnlocked: true);

      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets("the pane's edit opens the page unlocked, Cancel returns to "
        'view', (tester) async {
      var ended = 0;
      await pumpCertificationPage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      expect(find.textContaining('Editing'), findsOneWidget);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();

      expect(ended, 1);
    });

    testWidgets('locked, Delete is disabled under "Unlock to use these"', (
      tester,
    ) async {
      await pumpCertificationPage(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      final delete = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(
          PopupMenuItem<String>,
          l.certifications_detail_action_delete,
        ),
      );
      expect(delete.enabled, isFalse);
    });

    testWidgets('unlocked and clean, Delete asks', (tester) async {
      await pumpCertificationPage(tester);
      await unlock(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(RecordEditBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(
          PopupMenuItem<String>,
          l.certifications_detail_action_delete,
        ),
      );
      expect(item.enabled, isTrue);
      expect(find.text(l.recordEdit_unlockToUseThese), findsNothing);
      await tester.tap(find.text(l.certifications_detail_action_delete));
      await tester.pumpAndSettle();

      expect(
        find.text(l.certifications_detail_dialog_deleteTitle),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.certifications_detail_dialog_cancel),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
