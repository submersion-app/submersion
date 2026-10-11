import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for documents and their pages (#2613).
/// Every entry is entity-scoped: `type`, `side` and the rest are common
/// column names, and a bare key would relabel them on other tables. Columns
/// already catalogued under a shared key (title, notes, phone, dates, file
/// name, primary flag) need nothing here; page bytes are a BLOB.
final Map<String, ConflictField> documentFields = {};

final ConflictEnumLabeler _documentTypeLabeler = enumLabeler(
  DocumentType.values,
  (l, v) => documentTypeLabel(l, v),
);

final Map<String, ConflictField> documentOverrides = {
  'documents.type': ConflictField(
    (l) => l.documents_field_type,
    FieldKind.enumValue,
    enumLabel: _documentTypeLabeler,
  ),
  'documents.issuer': ConflictField(
    (l) => l.documents_field_issuer,
    FieldKind.shortText,
  ),
  'documents.referenceNumber': ConflictField(
    (l) => l.documents_field_referenceNumber,
    FieldKind.shortText,
  ),
  'documents.reminderLeadDays': ConflictField(
    (l) => l.documents_field_reminderLead,
    FieldKind.number,
  ),
  'documents.emergencyPhone': ConflictField(
    (l) => l.documents_field_emergencyPhone,
    FieldKind.shortText,
  ),
  'documentPages.pageIndex': ConflictField(
    (l) => l.settings_conflict_field_pageOrder,
    FieldKind.number,
  ),
  'documentPages.side': ConflictField(
    (l) => l.settings_conflict_field_cardSide,
    FieldKind.shortText,
  ),
  'documentPages.mimeType': ConflictField(
    (l) => l.settings_conflict_field_fileType,
    FieldKind.shortText,
  ),
  'documentPages.sizeBytes': ConflictField(
    (l) => l.settings_conflict_field_size,
    FieldKind.number,
  ),
};
