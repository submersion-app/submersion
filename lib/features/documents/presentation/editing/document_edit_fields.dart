import 'package:flutter/foundation.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_card_ids.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The document page's values a sitting edits, and the rules its form
/// keeps (issue #4527, phase 3).

final String _details = DocumentCardId.details.name;

/// A certification card is filed under its certification and stays there.
bool documentOwnerLocked(Document d) =>
    d.type == DocumentType.certificationCard;

/// A certification card stays one, and nothing else becomes one.
bool documentTypeLocked(Document d) => d.type == DocumentType.certificationCard;

/// The types [d] may take: a card only its own, anything else any type but
/// a card, as the form offers them.
List<DocumentType> documentTypeChoices(Document d) =>
    d.type == DocumentType.certificationCard
    ? const [DocumentType.certificationCard]
    : [
        for (final type in DocumentType.values)
          if (type != DocumentType.certificationCard) type,
      ];

/// A certification card has no title, expiry or reminder: its expiry lives
/// on the certification.
bool documentHasTitleExpiryAndReminder(Document d) =>
    d.type != DocumentType.certificationCard;

/// Only insurance keeps its phones and the primary mark.
bool documentKeepsPhonesAndPrimary(Document d) =>
    d.type == DocumentType.insurance;

/// The reminder lead as stored: the default is stored as none, so a later
/// change of the default reaches it.
int? storedReminderLead(int days) =>
    days == Document.defaultReminderLeadDays ? null : days;

/// A blank optional text is stored as none, as the form stores it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

EditField<DocumentRecord, V> _field<V>(
  String id,
  V Function(Document d) read,
  Document Function(Document d, V value) write, {
  bool Function(V a, V b)? equals,
}) => EditField<DocumentRecord, V>(
  id: id,
  cardId: _details,
  read: (r) => read(r.document),
  write: (r, v) => r.copyWith(document: write(r.document, v)),
  equals: equals,
);

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

final documentOwnerField = _field<DocumentOwner>(
  'owner',
  (d) => d.owner,
  (d, v) => d.copyWith(owner: v),
);

final documentTypeField = _field<DocumentType>(
  'type',
  (d) => d.type,
  (d, v) => d.copyWith(type: v),
);

final documentTitleField = _field<String>(
  'title',
  (d) => d.title,
  (d, v) => d.copyWith(title: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final documentIssuerField = _field<String?>(
  'issuer',
  (d) => d.issuer,
  (d, v) => d.copyWith(issuer: _orNone(v)),
  equals: _sameText,
);

final documentReferenceNumberField = _field<String?>(
  'referenceNumber',
  (d) => d.referenceNumber,
  (d, v) => d.copyWith(referenceNumber: _orNone(v)),
  equals: _sameText,
);

final documentEmergencyPhoneField = _field<String?>(
  'emergencyPhone',
  (d) => d.emergencyPhone,
  (d, v) => d.copyWith(emergencyPhone: _orNone(v)),
  equals: _sameText,
);

final documentPhoneField = _field<String?>(
  'phone',
  (d) => d.phone,
  (d, v) => d.copyWith(phone: _orNone(v)),
  equals: _sameText,
);

final documentPrimaryField = _field<bool>(
  'isPrimary',
  (d) => d.isPrimary,
  (d, v) => d.copyWith(isPrimary: v),
);

final documentIssueDateField = _field<DateTime?>(
  'issueDate',
  (d) => d.issueDate,
  (d, v) => d.copyWith(issueDate: v),
);

final documentExpiryDateField = _field<DateTime?>(
  'expiryDate',
  (d) => d.expiryDate,
  (d, v) => d.copyWith(expiryDate: v),
);

/// The reminder lead as stored ([storedReminderLead]): null is the default.
final documentReminderLeadField = _field<int?>(
  'reminderLeadDays',
  (d) => d.reminderLeadDays,
  (d, v) => d.copyWith(reminderLeadDays: v),
);

final documentNotesField = _field<String>(
  'notes',
  (d) => d.notes,
  (d, v) => d.copyWith(notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// The document's tags by id, compared as sets. Null when they could not
/// be read: the editor offers them read only and the save writes none.
final documentTagsField = EditField<DocumentRecord, List<String>?>(
  id: 'tags',
  cardId: _details,
  read: (r) => r.tagIds,
  write: (r, v) =>
      v == null ? r.copyWith(clearTags: true) : r.copyWith(tagIds: v),
  equals: DocumentRecord.sameTags,
);

/// Sets the document's type in [session]. The insurance-only values (its
/// phones and the primary mark) stay in the sitting whatever the type, as
/// the form's fields keep them, so switching away and back loses nothing;
/// they are dropped when a document of another type is saved
/// ([documentAsSaved]).
void setDocumentType(EditSession<DocumentRecord> session, DocumentType type) =>
    session.set(documentTypeField, type);

const _ownerFixedKey = 'document.ownerFixed';

/// Notes that [session]'s document is created for another record's open
/// Documents card (issue #4527, phase 3, plan 11): its owner is not
/// offered, as the form's `ownerFixed` hides it, and it is filed as
/// Personal while that record holds the link.
void markDocumentOwnerFixed(EditSession<DocumentRecord> session) =>
    session.remember(_ownerFixedKey, true);

/// Whether [session]'s owner is fixed ([markDocumentOwnerFixed]).
bool documentOwnerFixed(EditSession<DocumentRecord> session) =>
    !session.isDisposed && session.recall<bool>(_ownerFixedKey) == true;

/// [d] as it is saved: a document other than insurance keeps no phones and
/// is not primary, as the form saves it.
Document documentAsSaved(Document d) => documentKeepsPhonesAndPrimary(d)
    ? d
    : d.copyWith(emergencyPhone: null, phone: null, isPrimary: false);

/// The document's pages, in the order the viewer pages through them: the
/// Pages card's value. A page added in the sitting carries its content
/// until Save.
final documentPagesField = EditField<DocumentRecord, List<DocumentPage>>(
  id: 'pages',
  cardId: DocumentCardId.pages.name,
  read: (r) => r.pages,
  write: (r, v) => r.copyWith(pages: List.unmodifiable(v)),
  equals: listEquals,
);
