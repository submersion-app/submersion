import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/presentation/providers/document_owner_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_details_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'document_detail_page_unlock_harness.dart';

/// The document page edits in place (issue #4527): it opens locked, a
/// sitting edits its details, and one Save writes it.
void main() {
  final l = AppLocalizationsEn();

  // The tags field lists the diver's tags from the database.
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openDetails(WidgetTester tester) async {
    await tester.tap(find.byType(RecordPencilIcon).first);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpDocumentPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('the pane header has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpDocumentPage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('locked, no tap writes', (tester) async {
    final harness = await pumpDocumentPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await tester.tap(find.text('DAN'));
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('editing the title and saving writes one sitting', (
    tester,
  ) async {
    final harness = await pumpDocumentPage(tester);
    await unlock(tester);
    await openDetails(tester);

    await tester.enterText(find.byKey(const Key('document-title')), 'Trip');
    await tester.pumpAndSettle();
    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'details'});
    expect(harness.save.calls.single.after.document.title, 'Trip');
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('the reminder row shows when set', (tester) async {
    await pumpDocumentPage(
      tester,
      document: travel.copyWith(
        expiryDate: DateTime(2027, 1, 1),
        reminderLeadDays: 7,
      ),
    );

    expect(find.text(l.documents_field_reminderLead), findsOneWidget);
    expect(find.text(l.documents_field_reminderLeadDays(7)), findsOneWidget);
  });

  testWidgets('on a narrow window the details open while unlocked', (
    tester,
  ) async {
    await pumpDocumentPage(tester, pages: [storedPage(0)]);
    // Folded behind the panel while locked.
    expect(find.text('DAN'), findsNothing);

    await unlock(tester);

    expect(find.text('DAN'), findsOneWidget);
    expect(
      find.byTooltip(
        l.recordEdit_editCardTooltip(l.documents_editCard_details),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    "a card document's editor offers no owner, type, title or expiry change",
    (tester) async {
      await pumpDocumentPage(
        tester,
        document: Document(
          id: 'doc',
          diverId: 'd1',
          owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
          type: DocumentType.certificationCard,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await unlock(tester);
      await openDetails(tester);

      expect(find.byKey(const Key('document-title')), findsNothing);
      expect(find.text(l.documents_field_expiryDate), findsNothing);
      final type = tester.widget<DropdownButtonFormField<DocumentType>>(
        find.byKey(const Key('document-type')),
      );
      expect(type.onChanged, isNull);
      // The owner shows, locked to its certification.
      final owner = find.byKey(const ValueKey('document-owner-field'));
      expect(owner, findsOneWidget);
      expect(find.text(l.documents_owner_locked), findsOneWidget);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: owner, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
    },
  );

  testWidgets('a document refiled under a trip in Details saves that owner '
      'and names it', (tester) async {
    final harness = await pumpDocumentPage(
      tester,
      extraOverrides: [
        documentOwnerOptionsProvider(DocumentOwnerKind.trip).overrideWith(
          (ref) async => const [DocumentOwnerOption('t1', 'Bonaire')],
        ),
        documentOwnerLabelProvider.overrideWith(
          (ref, owner) async => owner.id == 't1'
              ? const DocumentOwnerOption('t1', 'Bonaire')
              : null,
        ),
      ],
    );
    await unlock(tester);
    await openDetails(tester);

    final owner = find.byKey(const ValueKey('document-owner-field'));
    await tester.ensureVisible(owner);
    await tester.tap(owner);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('owner-kind-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bonaire').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: owner, matching: find.text('Bonaire')),
      findsOneWidget,
    );

    await save(tester);

    final call = harness.save.calls.single;
    expect(
      call.after.document.owner,
      const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
    expect(call.cards, {'details'});
  });

  testWidgets('a tag typed into Details is saved with the sitting', (
    tester,
  ) async {
    final harness = await pumpDocumentPage(tester);
    await unlock(tester);
    await openDetails(tester);

    final input = find.descendant(
      of: find.byType(TagInputWidget),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Club');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await save(tester);

    final call = harness.save.calls.single;
    expect(call.after.tagIds, hasLength(1));
    expect(call.cards, {'details'});
  });

  testWidgets('tags that could not be read are shown read only', (
    tester,
  ) async {
    await pumpDocumentPage(tester, tagIds: null);
    await unlock(tester);
    await openDetails(tester);

    final browse = tester.widget<TextButton>(
      find.byKey(const ValueKey('document_details_tags_browse')),
    );
    expect(browse.onPressed, isNull);
  });

  testWidgets('a record that cannot be read says so, with a way back', (
    tester,
  ) async {
    await pumpDocumentPage(tester, recordReadError: StateError('broken'));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('broken'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('a record that is gone says so instead of waiting', (
    tester,
  ) async {
    await pumpDocumentPage(tester, recordMissing: true);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l.documents_empty), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpDocumentPage(tester);
    await unlock(tester);
    await openDetails(tester);
    await tester.enterText(find.byKey(const Key('document-title')), 'Trip');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  group('the Pages card', () {
    Finder pagesPencil() =>
        find.byTooltip(l.recordEdit_editCardTooltip(l.documents_pages_title));

    Future<void> addFilePage(WidgetTester tester) async {
      await tester.tap(find.text(l.documents_pages_add));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.documents_pages_addFile));
      await tester.pumpAndSettle();
    }

    testWidgets('locked, the page shows no Pages header', (tester) async {
      await pumpDocumentPage(tester, pages: [storedPage(0)]);

      expect(find.text(l.documents_pages_title), findsNothing);
    });

    testWidgets('a page added and saved is written with the sitting', (
      tester,
    ) async {
      final harness = await pumpDocumentPage(tester, pages: [storedPage(0)]);
      await unlock(tester);
      await tester.tap(pagesPencil());
      await tester.pumpAndSettle();
      await addFilePage(tester);

      await save(tester);

      final call = harness.save.calls.single;
      expect(call.cards, {'pages'});
      expect(call.after.pages, hasLength(2));
    });

    testWidgets('a document with no pages offers Pages in the strip', (
      tester,
    ) async {
      await pumpDocumentPage(tester);
      await unlock(tester);

      expect(
        find.descendant(
          of: find.byType(AddStrip),
          matching: find.text(l.documents_pages_title),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a page added while the title changes underneath keeps both', (
      tester,
    ) async {
      final harness = await pumpDocumentPage(tester, pages: [storedPage(0)]);
      await unlock(tester);
      await tester.tap(pagesPencil());
      await tester.pumpAndSettle();
      await addFilePage(tester);

      final now = harness.stored.state!;
      harness.stored.state = now.copyWith(
        document: now.document.copyWith(title: 'Renamed'),
      );
      await tester.pumpAndSettle();
      await save(tester);

      final after = harness.save.calls.single.after;
      expect(after.document.title, 'Renamed');
      expect(after.pages, hasLength(2));
    });
  });

  group('addresses and operations', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
    }

    Finder deleteItem() => find.text(l.common_action_delete);

    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpDocumentPage(tester, openUnlocked: true);

      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets('a pane opened for editing returns to view when it ends', (
      tester,
    ) async {
      var ended = 0;
      await pumpDocumentPage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended += 1,
      );

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();

      expect(ended, 1);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets('locked, Delete is disabled under "Unlock to use these"', (
      tester,
    ) async {
      final harness = await pumpDocumentPage(tester);
      await openMenu(tester);

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      await tester.tap(deleteItem());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.mutations.deleted, isEmpty);
    });

    testWidgets('unlocked and clean, Delete asks and deletes', (tester) async {
      final harness = await pumpDocumentPage(tester);
      await unlock(tester);
      await openMenu(tester);

      await tester.tap(deleteItem());
      await tester.pumpAndSettle();
      expect(find.text(l.documents_delete_title), findsOneWidget);
      await tester.tap(deleteItem().last);
      await tester.pumpAndSettle();

      expect(harness.mutations.deleted, ['doc']);
    });
  });

  group('review fixes', () {
    testWidgets('on a narrow window the open Details editor scrolls', (
      tester,
    ) async {
      await pumpDocumentPage(tester, pages: [storedPage(0)]);
      await unlock(tester);

      await tester.tap(
        find.byTooltip(
          l.recordEdit_editCardTooltip(l.documents_editCard_details),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('document-title')), findsOneWidget);
    });

    testWidgets("an owner changed in the sitting drops the old owner's name", (
      tester,
    ) async {
      await pumpDocumentPage(
        tester,
        document: travel.copyWith(
          owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
        ),
        ownerLabel: 'Bonaire',
      );
      expect(find.text('Bonaire'), findsOneWidget);
      await unlock(tester);

      final page = tester.state(find.byType(DocumentDetailPage)) as dynamic;
      (page.editController.session as EditSession<DocumentRecord>).set(
        documentOwnerField,
        const DocumentOwner.personal(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bonaire'), findsNothing);
    });
  });

  testWidgets('tags changed in the sitting show on the closed card', (
    tester,
  ) async {
    await pumpDocumentPage(tester);
    await unlock(tester);

    final page = tester.state(find.byType(DocumentDetailPage)) as dynamic;
    holdDocumentTags(
      page.editController.session as EditSession<DocumentRecord>,
      [
        Tag(
          id: 't2',
          name: 'Club',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Club'), findsOneWidget);
  });

  testWidgets('tags changed back to the stored set follow the stored tags', (
    tester,
  ) async {
    await pumpDocumentPage(tester);
    await unlock(tester);
    final page = tester.state(find.byType(DocumentDetailPage)) as dynamic;
    final session = page.editController.session as EditSession<DocumentRecord>;
    final club = Tag(
      id: 't2',
      name: 'Club',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    holdDocumentTags(session, [club]);
    // Back to the stored set (none): no change, and nothing held to show.
    holdDocumentTags(session, const []);
    await tester.pumpAndSettle();

    expect(session.isDirty, isFalse);
    expect(heldDocumentTags(session), isNull);
    expect(find.text('Club'), findsNothing);
  });
}
