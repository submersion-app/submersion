import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_file_gate.dart';

void main() {
  test('pdf, word and text are accepted as-is', () {
    for (final (name, mime) in [
      ('a.pdf', 'application/pdf'),
      ('a.DOC', 'application/msword'),
      (
        'a.docx',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      ('a.txt', 'text/plain'),
    ]) {
      final v = checkDocumentFile(fileName: name, sizeBytes: 10);
      expect(v, isA<DocumentFileAccepted>(), reason: name);
      v as DocumentFileAccepted;
      expect(v.mimeType, mime, reason: name);
      expect(v.needsImageReencode, isFalse, reason: name);
    }
  });

  test('picked images are accepted and re-encoded', () {
    final v = checkDocumentFile(fileName: 'scan.PNG', sizeBytes: 10);
    expect((v as DocumentFileAccepted).needsImageReencode, isTrue);
  });

  test('HEIC files are refused: the image decoder cannot read them', () {
    expect(
      checkDocumentFile(fileName: 'scan.heic', sizeBytes: 10),
      isA<DocumentFileUnsupported>(),
    );
    expect(kDocumentPickerExtensions, isNot(contains('heic')));
  });

  test('exactly 10 MB is accepted, one byte more is refused', () {
    expect(
      checkDocumentFile(fileName: 'a.pdf', sizeBytes: kMaxDocumentPageBytes),
      isA<DocumentFileAccepted>(),
    );
    expect(
      checkDocumentFile(
        fileName: 'a.pdf',
        sizeBytes: kMaxDocumentPageBytes + 1,
      ),
      isA<DocumentFileTooLarge>(),
    );
  });

  test('other extensions and no extension are refused', () {
    expect(
      checkDocumentFile(fileName: 'a.gpx', sizeBytes: 1),
      isA<DocumentFileUnsupported>(),
    );
    expect(
      checkDocumentFile(fileName: 'README', sizeBytes: 1),
      isA<DocumentFileUnsupported>(),
    );
  });
}
