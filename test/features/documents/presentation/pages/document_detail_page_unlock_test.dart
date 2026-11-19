import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'document_detail_page_unlock_harness.dart';

/// The document page edits in place behind the phase 3 switch (issue
/// #4527): it opens locked, a sitting edits its details, and one Save
/// writes it.
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

  testWidgets('with the switch off there is no lock', (tester) async {
    await pumpDocumentPage(tester, unlockEditing: false);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
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
    expect(find.byType(RecordPencilIcon), findsOneWidget);
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
    },
  );

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
}
