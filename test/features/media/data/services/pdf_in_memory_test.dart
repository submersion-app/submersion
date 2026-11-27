import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:submersion/features/media/data/services/pdf_in_memory.dart';

/// Issue #4785. pdfrx loads PDF bytes over 1 MB on demand: pdfium, on the
/// worker isolate, blocks in a native wait while the main isolate copies each
/// block across. On Windows that wait could miss its wake-up, which left the
/// worker asleep for good: the viewer stayed blank and quitting hung. These
/// pin every byte source to pdfrx's in-memory load, which has no such wait.
void main() {
  // Above pdfrx's 1 MB default, where the on-demand path used to take over.
  final large = Uint8List(3 * 1024 * 1024);

  group('inMemoryPdfDocumentRef', () {
    test('holds a PDF over 1 MB in native memory instead of reading it on '
        'demand', () {
      final ref = inMemoryPdfDocumentRef(large, sourceName: 'doc-1');

      expect(ref, isA<PdfDocumentRefData>());
      final data = ref as PdfDocumentRefData;
      expect(data.maxSizeToCacheOnMemory, large.length);
      expect(identical(data.data, large), isTrue);
    });

    test('keys the document by its source name', () {
      final ref = inMemoryPdfDocumentRef(large, sourceName: 'doc-1');

      expect(ref.key, PdfDocumentRefKey('doc-1'));
    });

    test('keeps a small PDF in memory too', () {
      final small = Uint8List(10);

      final ref =
          inMemoryPdfDocumentRef(small, sourceName: 'doc-2')
              as PdfDocumentRefData;

      expect(ref.maxSizeToCacheOnMemory, small.length);
    });
  });
}
