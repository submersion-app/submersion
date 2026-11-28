import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:submersion/features/media/data/services/pdf_in_memory.dart';
import 'package:submersion/features/media/presentation/widgets/in_memory_pdf_viewer.dart';

/// Issue #4785. Building the widget loads nothing, so this runs without a
/// pdfium binary: it checks the document the viewer would open.
void main() {
  final large = Uint8List(3 * 1024 * 1024);

  test('opens the PDF from native memory, keyed by its source name', () {
    final viewer = inMemoryPdfViewer(large, sourceName: 'doc-1');

    final ref = viewer.documentRef as PdfDocumentRefData;
    expect(ref.maxSizeToCacheOnMemory, inMemoryPdfLimitBytes);
    expect(ref.key, PdfDocumentRefKey('doc-1'));
  });

  test('passes the viewer params through', () {
    const params = PdfViewerParams(margin: 12);

    final viewer = inMemoryPdfViewer(
      large,
      sourceName: 'doc-1',
      params: params,
    );

    expect(viewer.params, same(params));
  });
}
