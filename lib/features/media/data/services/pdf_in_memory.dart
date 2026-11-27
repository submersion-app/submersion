import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// A [PdfDocumentRef] for PDF [bytes] that pdfium loads from native memory.
///
/// pdfrx copies a PDF of up to 1 MB into native memory and reads anything
/// larger on demand: pdfium, on pdfrx's worker isolate, then blocks in a
/// native wait for every block while the main isolate copies it across. On
/// Windows that wait could miss its wake-up and never return, which stalled
/// every PDF call after it: the viewer stayed blank and quitting hung
/// (issue #4785). The bytes are already in memory here, so raising the limit
/// to their own size costs one native copy and removes the wait.
PdfDocumentRef inMemoryPdfDocumentRef(
  Uint8List bytes, {
  required String sourceName,
}) => PdfDocumentRefData(
  bytes,
  sourceName: sourceName,
  maxSizeToCacheOnMemory: bytes.length,
);

/// Opens PDF [bytes] from native memory; see [inMemoryPdfDocumentRef].
Future<PdfDocument> openInMemoryPdf(Uint8List bytes) =>
    PdfDocument.openData(bytes, maxSizeToCacheOnMemory: bytes.length);
