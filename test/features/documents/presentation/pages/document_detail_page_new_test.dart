import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_details_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/document_new_sitting.dart';
import 'package:submersion/features/documents/presentation/editing/document_pages_card_editor.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'document_detail_page_unlock_harness.dart';

/// A new document opens on the document page, already unlocked (issue
/// #4527, phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Finder titleField() =>
      find.widgetWithText(TextFormField, l.documents_field_title);

  Future<void> typeTitle(WidgetTester tester, String title) async {
    await tester.enterText(titleField(), title);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
  }

  testWidgets('a new document opens unlocked with Details and Pages open', (
    tester,
  ) async {
    await pumpNewDocumentPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.documents_edit_newTitle), findsOneWidget);
    expect(find.byType(DocumentDetailsCardEditor), findsOneWidget);
    expect(find.byType(DocumentPagesCardEditor), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('Save waits for the first entry', (tester) async {
    final harness = await pumpNewDocumentPage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeTitle(tester, 'Nitrox');
    await tapSave(tester);
    expect(harness.save.creates.single.record.document.title, 'Nitrox');
  });

  testWidgets('an untouched new document leaves without asking', (
    tester,
  ) async {
    final harness = await pumpNewDocumentPage(tester);

    await tapCancel(tester);

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('an entry asks before leaving', (tester) async {
    final harness = await pumpNewDocumentPage(tester);
    await typeTitle(tester, 'Nitrox');

    await tapCancel(tester);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsOneWidget);

    await tapCancel(tester);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();
    expect(harness.poppedAtAll, isTrue);
    expect(harness.save.creates, isEmpty);
  });

  testWidgets('Save creates the document, re-arms it and pops its id', (
    tester,
  ) async {
    final harness = await pumpNewDocumentPage(tester);
    await typeTitle(tester, 'Nitrox');

    await tapSave(tester);

    final created = harness.save.creates.single;
    expect(created.cards, contains('details'));
    expect(harness.popped, created.record.id);
    expect(harness.mutations.rearmed, [created.record.id]);
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewDocumentPage(tester, embedded: true);
    await typeTitle(tester, 'Nitrox');

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.record.id]);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewDocumentPage(tester);
    await typeTitle(tester, 'Nitrox');
    harness.save.fail = true;

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Nitrox'), findsWidgets);

    harness.save.fail = false;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.record.id,
      harness.save.creates.first.record.id,
    );
  });

  testWidgets('a type from the list is a change: Save is enabled at once', (
    tester,
  ) async {
    final harness = await pumpNewDocumentPage(
      tester,
      request: const NewDocumentRequest(type: DocumentType.permit),
    );

    await tapSave(tester);

    expect(
      harness.save.creates.single.record.document.type,
      DocumentType.permit,
    );
  });

  for (final hasPrimary in [false, true]) {
    testWidgets(
      'an insurance is saved primary only as the first (has one: $hasPrimary)',
      (tester) async {
        final harness = await pumpNewDocumentPage(
          tester,
          request: const NewDocumentRequest(type: DocumentType.insurance),
          hasPrimary: hasPrimary,
        );
        await tapSave(tester);
        expect(
          harness.save.creates.single.record.document.isPrimary,
          !hasPrimary,
        );
      },
    );
  }

  testWidgets('a card document has no title, expiry or reminder', (
    tester,
  ) async {
    await pumpNewDocumentPage(
      tester,
      request: const NewDocumentRequest(type: DocumentType.certificationCard),
    );

    expect(titleField(), findsNothing);
    expect(find.text(l.documents_field_expiryDate), findsNothing);
    expect(find.text(l.documents_field_reminderLead), findsNothing);
  });

  testWidgets('a fixed owner is not offered, and is saved as Personal', (
    tester,
  ) async {
    final harness = await pumpNewDocumentPage(
      tester,
      request: const NewDocumentRequest(ownerFixed: true),
    );

    expect(find.byKey(const ValueKey('document-owner-field')), findsNothing);
    await typeTitle(tester, 'Waiver');
    await tapSave(tester);
    expect(
      harness.save.creates.single.record.document.owner,
      const DocumentOwner.personal(),
    );
  });

  testWidgets('nothing is written before Save', (tester) async {
    final harness = await pumpNewDocumentPage(tester);
    await typeTitle(tester, 'Nitrox');

    await tapCancel(tester);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });
}
