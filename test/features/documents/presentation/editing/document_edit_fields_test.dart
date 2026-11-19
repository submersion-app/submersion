import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

Document _doc(DocumentType type, {bool primary = false}) => Document(
  id: 'doc',
  diverId: 'd1',
  owner: type == DocumentType.certificationCard
      ? const DocumentOwner(DocumentOwnerKind.certification, 'c1')
      : const DocumentOwner.personal(),
  type: type,
  title: 'Travel',
  emergencyPhone: '911',
  phone: '555',
  isPrimary: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DocumentRecord _record(DocumentType type, {bool primary = false}) =>
    DocumentRecord(
      document: _doc(type, primary: primary),
      pages: const [],
      tagIds: const ['t1', 't2'],
    );

/// The document's editing rules, kept from its form (issue #4527, phase 3).
void main() {
  test('a certification card locks its owner and type and has no title, expiry '
      'or reminder', () {
    final card = _doc(DocumentType.certificationCard);

    expect(documentOwnerLocked(card), isTrue);
    expect(documentTypeLocked(card), isTrue);
    expect(documentHasTitleExpiryAndReminder(card), isFalse);
    expect(documentTypeChoices(card), [DocumentType.certificationCard]);
  });

  test('another document chooses any type but a card', () {
    final permit = _doc(DocumentType.permit);

    expect(documentOwnerLocked(permit), isFalse);
    expect(documentTypeLocked(permit), isFalse);
    expect(documentHasTitleExpiryAndReminder(permit), isTrue);
    expect(
      documentTypeChoices(permit),
      isNot(contains(DocumentType.certificationCard)),
    );
  });

  test('only insurance keeps its phones and primary', () {
    expect(documentKeepsPhonesAndPrimary(_doc(DocumentType.insurance)), isTrue);
    expect(documentKeepsPhonesAndPrimary(_doc(DocumentType.permit)), isFalse);
  });

  test('switching away from insurance and back keeps the phones', () {
    final session = EditSession(_record(DocumentType.insurance, primary: true));
    addTearDown(session.dispose);

    setDocumentType(session, DocumentType.permit);
    setDocumentType(session, DocumentType.insurance);

    final working = session.working.document;
    expect(working.emergencyPhone, '911');
    expect(working.phone, '555');
    expect(working.isPrimary, isTrue);
    expect(session.isDirty, isFalse);
  });

  test('a document saved as other than insurance keeps no phones', () {
    final saved = documentAsSaved(
      _doc(
        DocumentType.insurance,
        primary: true,
      ).copyWith(type: DocumentType.permit),
    );

    expect(saved.emergencyPhone, isNull);
    expect(saved.phone, isNull);
    expect(saved.isPrimary, isFalse);
  });

  test('the default reminder is stored as none', () {
    expect(storedReminderLead(Document.defaultReminderLeadDays), isNull);
    expect(storedReminderLead(7), 7);
    expect(storedReminderLead(0), 0);
  });

  test('a blank text is stored as none', () {
    final session = EditSession(_record(DocumentType.permit));
    addTearDown(session.dispose);

    session.set(documentIssuerField, '  ');

    expect(session.working.document.issuer, isNull);
  });

  test('tags compare as sets', () {
    final session = EditSession(_record(DocumentType.permit));
    addTearDown(session.dispose);

    session.set(documentTagsField, ['t2', 't1']);

    expect(session.isDirty, isFalse);
  });
}
