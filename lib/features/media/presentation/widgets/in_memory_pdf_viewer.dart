import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'package:submersion/features/media/data/services/pdf_in_memory.dart';

/// A [PdfViewer] over PDF [bytes] that pdfium loads from native memory when
/// they fit in [inMemoryPdfLimitBytes], so it does not wait on the main
/// isolate for each block (issue #4785). Both the attachment viewer and the
/// documents page viewer build theirs here.
PdfViewer inMemoryPdfViewer(
  Uint8List bytes, {
  required String sourceName,
  PdfViewerParams params = const PdfViewerParams(),
}) => PdfViewer(
  inMemoryPdfDocumentRef(bytes, sourceName: sourceName),
  params: params,
);
