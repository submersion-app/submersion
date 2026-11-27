import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// The largest PDF that pdfium is handed whole, from native memory.
///
/// pdfrx copies a PDF of up to 1 MB into native memory and reads anything
/// larger on demand: pdfium, on pdfrx's worker isolate, then blocks in a
/// native wait for every block while the main isolate copies it across. On
/// Windows that wait could miss its wake-up and never return, which stalled
/// every PDF call after it: the viewer stayed blank and quitting hung
/// (issue #4785). pdfrx 2.6.0 fixed that wait, and loading in memory removes
/// it altogether for the PDFs divers attach, at the cost of one native copy.
///
/// Above this size the copy costs more than the wait it removes: an attached
/// PDF has no size limit, and a scanned manual of hundreds of MB would need
/// that much again in native memory while it is open. Such a file keeps
/// pdfrx's on-demand reads.
const inMemoryPdfLimitBytes = 64 * 1024 * 1024;

/// A [PdfDocumentRef] for PDF [bytes] that pdfium loads from native memory
/// when they fit in [inMemoryPdfLimitBytes].
PdfDocumentRef inMemoryPdfDocumentRef(
  Uint8List bytes, {
  required String sourceName,
}) => PdfDocumentRefData(
  bytes,
  sourceName: sourceName,
  maxSizeToCacheOnMemory: inMemoryPdfLimitBytes,
);

// Opening needs pdfium, which flutter_test cannot load.
// coverage:ignore-start
/// Opens PDF [bytes] from native memory when they fit in
/// [inMemoryPdfLimitBytes]; see [inMemoryPdfDocumentRef].
Future<PdfDocument> openInMemoryPdf(Uint8List bytes) =>
    PdfDocument.openData(bytes, maxSizeToCacheOnMemory: inMemoryPdfLimitBytes);
// coverage:ignore-end
