import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'package:submersion/core/services/logger_service.dart';

/// Signature of the PDF page-1 render seam, injectable so tests do not need
/// a pdfium binary. Matches [PdfPageRenderer.renderFirstPageJpeg].
///
/// Declared here rather than beside either consumer: both the upload
/// pipeline's `ThumbnailGenerator` and the grid's `PdfThumbnailService` take
/// the seam, and neither feature should have to import the other to name it.
typedef PdfThumbRenderer =
    Future<Uint8List?> Function({
      File? file,
      Uint8List? bytes,
      int maxDimension,
      int quality,
    });

/// Renders the first page of a PDF to JPEG bytes for thumbnails.
///
/// Every failure path returns null: thumbnail absence must never block an
/// upload or a grid render (same contract as ThumbnailGenerator).
class PdfPageRenderer {
  PdfPageRenderer._();

  static final _log = LoggerService.forClass(PdfPageRenderer);
  static bool _initialized = false;

  /// Engine bootstrap, injectable for tests. The Flutter runtime loads the
  /// bundled pdfium via [pdfrxFlutterInitialize]; pure-Dart test hosts can
  /// substitute [pdfrxInitialize] (which fetches a host pdfium build).
  static Future<void> Function() initializer = pdfrxFlutterInitialize;

  static Future<Uint8List?> renderFirstPageJpeg({
    File? file,
    Uint8List? bytes,
    int maxDimension = 512,
    int quality = 80,
  }) async {
    assert((file == null) != (bytes == null), 'pass exactly one source');
    PdfDocument? document;
    try {
      if (!_initialized) {
        await initializer();
        _initialized = true;
      }
      document = file != null
          ? await PdfDocument.openFile(file.path)
          : await PdfDocument.openData(bytes!);
      if (document.pages.isEmpty) return null;
      final page = document.pages[0];
      final longest = page.width > page.height ? page.width : page.height;
      final scale = maxDimension / longest;
      final pageImage = await page.render(
        width: (page.width * scale).round(),
        height: (page.height * scale).round(),
      );
      if (pageImage == null) return null;
      try {
        final image = pageImage.createImageNF();
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      } finally {
        pageImage.dispose();
      }
    } on Exception catch (e) {
      _log.warning('PDF page render failed: $e');
      return null;
    } finally {
      await document?.dispose();
    }
  }
}
