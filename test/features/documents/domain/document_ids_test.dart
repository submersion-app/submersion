import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

void main() {
  test('ids are stable for the same source', () {
    expect(documentInsuranceId('d1'), documentInsuranceId('d1'));
    expect(
      documentCertificationCardId('c1'),
      documentCertificationCardId('c1'),
    );
  });

  test('ids differ by kind and by source', () {
    final ids = {
      documentInsuranceId('d1'),
      documentInsuranceId('d2'),
      documentMedicalClearanceId('d1'),
      documentCertificationCardId('d1'),
    };
    expect(ids, hasLength(4));
  });

  test('card page ids differ by side', () {
    final doc = documentCertificationCardId('c1');
    expect(
      documentCardPageId(doc, DocumentPageSide.front),
      isNot(documentCardPageId(doc, DocumentPageSide.back)),
    );
  });

  test('ids are version 5 UUIDs pinned to the namespace', () {
    // A namespace edit after release would orphan every migrated row on
    // devices that upgrade later, so the value is pinned.
    expect(documentInsuranceId('d1'), hasLength(36));
    expect(documentInsuranceId('d1')[14], '5');
    expect(kDocumentNamespace, 'c3a5f0d2-8b14-4e6f-9a27-5d0e1b4c7f93');
  });

  test('converted gear file ids are stable and distinct', () {
    expect(documentEquipmentFileId('m1'), documentEquipmentFileId('m1'));
    expect(documentEquipmentFileId('m1'), isNot(documentEquipmentFileId('m2')));
    final doc = documentEquipmentFileId('m1');
    expect(documentEquipmentFilePageId(doc), isNot(doc));
    expect(doc[14], '5');
  });
}
