import 'package:uuid/uuid.dart';

import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// Fixed namespace for document ids derived from their source rows. Two
/// devices that migrate the same library independently produce the same
/// ids, so the rows merge by id instead of duplicating. Never change it.
const String kDocumentNamespace = 'c3a5f0d2-8b14-4e6f-9a27-5d0e1b4c7f93';

String _v5(String key) =>
    const Uuid().v5(kDocumentNamespace, 'submersion:document:$key');

/// The diver's primary insurance document created from the old diver row
/// columns (or by an import that hands a new diver an insurance).
String documentInsuranceId(String diverId) => _v5('insurance:$diverId');

/// The medical clearance document created from the old diver row column.
String documentMedicalClearanceId(String diverId) =>
    _v5('medicalClearance:$diverId');

/// A certification's card document, holding its front and back images.
String documentCertificationCardId(String certificationId) =>
    _v5('certificationCard:$certificationId');

/// The front or back page of a card document.
String documentCardPageId(String documentId, DocumentPageSide side) =>
    _v5('page:$documentId:${side.name}');
