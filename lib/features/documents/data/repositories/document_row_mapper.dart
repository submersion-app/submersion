import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// SQL column of each non-personal owner kind.
const Map<DocumentOwnerKind, String> kDocumentOwnerColumns = {
  DocumentOwnerKind.dive: 'dive_id',
  DocumentOwnerKind.site: 'site_id',
  DocumentOwnerKind.trip: 'trip_id',
  DocumentOwnerKind.equipment: 'equipment_id',
  DocumentOwnerKind.course: 'course_id',
  DocumentOwnerKind.certification: 'certification_id',
  DocumentOwnerKind.buddy: 'buddy_id',
  DocumentOwnerKind.diveCenter: 'dive_center_id',
};

DateTime? _date(int? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

/// The first owner link set on [r]; none means personal.
DocumentOwner ownerOfRow(DocumentRow r) {
  final links = <DocumentOwnerKind, String?>{
    DocumentOwnerKind.dive: r.diveId,
    DocumentOwnerKind.site: r.siteId,
    DocumentOwnerKind.trip: r.tripId,
    DocumentOwnerKind.equipment: r.equipmentId,
    DocumentOwnerKind.course: r.courseId,
    DocumentOwnerKind.certification: r.certificationId,
    DocumentOwnerKind.buddy: r.buddyId,
    DocumentOwnerKind.diveCenter: r.diveCenterId,
  };
  for (final e in links.entries) {
    final id = e.value;
    if (id != null) return DocumentOwner(e.key, id);
  }
  return const DocumentOwner.personal();
}

Document documentFromRow(DocumentRow r) => Document(
  id: r.id,
  diverId: r.diverId,
  owner: ownerOfRow(r),
  type: DocumentType.fromStorage(r.type),
  title: r.title,
  issuer: r.issuer,
  referenceNumber: r.referenceNumber,
  issueDate: _date(r.issueDate),
  expiryDate: _date(r.expiryDate),
  reminderLeadDays: r.reminderLeadDays,
  emergencyPhone: r.emergencyPhone,
  phone: r.phone,
  isPrimary: r.isPrimary,
  notes: r.notes,
  createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
);

/// The row for [d]. Insurance-only fields are dropped for other types, so
/// a type change never leaves a stale primary flag or phone behind.
DocumentsCompanion documentCompanion(Document d, {required int updatedAt}) {
  String? link(DocumentOwnerKind k) => d.owner.kind == k ? d.owner.id : null;
  final insurance = d.type == DocumentType.insurance;
  return DocumentsCompanion(
    id: Value(d.id),
    diverId: Value(d.diverId),
    diveId: Value(link(DocumentOwnerKind.dive)),
    siteId: Value(link(DocumentOwnerKind.site)),
    tripId: Value(link(DocumentOwnerKind.trip)),
    equipmentId: Value(link(DocumentOwnerKind.equipment)),
    courseId: Value(link(DocumentOwnerKind.course)),
    certificationId: Value(link(DocumentOwnerKind.certification)),
    buddyId: Value(link(DocumentOwnerKind.buddy)),
    diveCenterId: Value(link(DocumentOwnerKind.diveCenter)),
    type: Value(d.type.storage),
    title: Value(d.title),
    issuer: Value(d.issuer),
    referenceNumber: Value(d.referenceNumber),
    issueDate: Value(d.issueDate?.millisecondsSinceEpoch),
    expiryDate: Value(d.expiryDate?.millisecondsSinceEpoch),
    reminderLeadDays: Value(d.reminderLeadDays),
    emergencyPhone: Value(insurance ? d.emergencyPhone : null),
    phone: Value(insurance ? d.phone : null),
    isPrimary: Value(insurance && d.isPrimary),
    notes: Value(d.notes),
    createdAt: Value(d.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(updatedAt),
  );
}

DocumentPage pageFromRow(DocumentPageRow r) => DocumentPage(
  id: r.id,
  documentId: r.documentId,
  pageIndex: r.pageIndex,
  side: DocumentPageSide.fromStorage(r.side),
  fileName: r.fileName,
  mimeType: r.mimeType,
  sizeBytes: r.sizeBytes,
  bytes: r.bytes,
  createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
);
