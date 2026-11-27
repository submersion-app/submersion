import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:submersion/features/media/data/services/pdf_in_memory.dart';

/// Issue #4785. pdfrx loads PDF bytes over 1 MB on demand: pdfium, on the
/// worker isolate, blocks in a native wait while the main isolate copies each
/// block across. On Windows that wait could miss its wake-up, which left the
/// worker asleep for good: the viewer stayed blank and quitting hung. These
/// pin byte sources up to the cap to pdfrx's in-memory load, which has no
/// such wait. pdfrx compares a document's size to the limit as size <= limit.
void main() {
  // Above pdfrx's 1 MB default, where the on-demand path used to take over.
  final large = Uint8List(3 * 1024 * 1024);

  test('the cap is 64 MB, well above the 1 MB default', () {
    expect(inMemoryPdfLimitBytes, 64 * 1024 * 1024);
  });

  group('inMemoryPdfDocumentRef', () {
    test('holds a PDF over 1 MB in native memory instead of reading it on '
        'demand', () {
      final ref = inMemoryPdfDocumentRef(large, sourceName: 'doc-1');

      expect(ref, isA<PdfDocumentRefData>());
      final data = ref as PdfDocumentRefData;
      expect(data.maxSizeToCacheOnMemory, inMemoryPdfLimitBytes);
      expect(large.length, lessThanOrEqualTo(data.maxSizeToCacheOnMemory!));
      expect(identical(data.data, large), isTrue);
    });

    test('keys the document by its source name', () {
      final ref = inMemoryPdfDocumentRef(large, sourceName: 'doc-1');

      expect(ref.key, PdfDocumentRefKey('doc-1'));
    });

    test('keeps the same cap whatever the document size', () {
      // A fixed cap, not the document's own size: a PDF of hundreds of MB is
      // left to on-demand reads instead of being copied whole.
      final small =
          inMemoryPdfDocumentRef(Uint8List(10), sourceName: 'doc-2')
              as PdfDocumentRefData;
      final big =
          inMemoryPdfDocumentRef(large, sourceName: 'doc-3')
              as PdfDocumentRefData;

      expect(small.maxSizeToCacheOnMemory, inMemoryPdfLimitBytes);
      expect(big.maxSizeToCacheOnMemory, inMemoryPdfLimitBytes);
    });
  });
}
