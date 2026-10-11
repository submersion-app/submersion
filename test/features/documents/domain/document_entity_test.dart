import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

void main() {
  final base = Document(
    id: 'a',
    diverId: 'd',
    owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    type: DocumentType.permit,
    expiryDate: DateTime(2027),
    issuer: 'Park',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('copyWith can clear a nullable field', () {
    final cleared = base.copyWith(expiryDate: null, issuer: null);
    expect(cleared.expiryDate, isNull);
    expect(cleared.issuer, isNull);
  });

  test('copyWith without arguments keeps nullable fields', () {
    expect(base.copyWith(), base);
  });

  test('effective lead defaults to 30, 0 stays 0', () {
    expect(base.effectiveReminderLeadDays, 30);
    expect(base.copyWith(reminderLeadDays: 0).effectiveReminderLeadDays, 0);
  });

  test('a card never reminds, an undated document never reminds', () {
    expect(base.remindsOnExpiry, isTrue);
    expect(
      base.copyWith(type: DocumentType.certificationCard).remindsOnExpiry,
      isFalse,
    );
    expect(base.copyWith(expiryDate: null).remindsOnExpiry, isFalse);
  });

  test('storage round trip, unknown falls back', () {
    for (final t in DocumentType.values) {
      expect(DocumentType.fromStorage(t.storage), t);
    }
    for (final k in DocumentOwnerKind.values) {
      expect(DocumentOwnerKind.fromStorage(k.storage), k);
    }
    expect(DocumentType.fromStorage('nope'), DocumentType.other);
    expect(DocumentOwnerKind.fromStorage(null), DocumentOwnerKind.personal);
  });

  test('page kinds and withoutBytes', () {
    final page = DocumentPage(
      id: 'p',
      documentId: 'a',
      pageIndex: 0,
      fileName: 'a.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1,
      bytes: Uint8List.fromList([1]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(page.isPdf, isTrue);
    expect(page.isImage, isFalse);
    expect(page.withoutBytes().bytes, isNull);
    expect(page.withoutBytes(), page);
    expect(DocumentPageSide.fromStorage('back'), DocumentPageSide.back);
    expect(DocumentPageSide.fromStorage(null), isNull);
  });
}
