import 'dart:io';
import 'dart:isolate';
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

/// A page-1 render with the document's page count, for the large site card
/// (issue #1039).
class PdfPagePreview {
  const PdfPagePreview({required this.jpeg, required this.pageCount});

  final Uint8List jpeg;

  /// Null when it is unknown (a cache entry written without one).
  final int? pageCount;
}

/// Signature of the large-preview seam, injectable for the same reason as
/// [PdfThumbRenderer]. Matches [PdfPageRenderer.renderFirstPagePreview].
typedef PdfPreviewRenderer =
    Future<PdfPagePreview?> Function({
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
  }) async => (await renderFirstPagePreview(
    file: file,
    bytes: bytes,
    maxDimension: maxDimension,
    quality: quality,
  ))?.jpeg;

  /// JPEG-encodes a BGRA page bitmap on a background isolate.
  ///
  /// package:image is pure Dart: converting and encoding a 2048 px site card
  /// render takes long enough to drop frames, and the caller is a widget on
  /// the UI isolate. Raw pixels and two ints are the sendable form of the
  /// page, so they cross; the image object is built on the other side.
  static Future<Uint8List> encodeBgraJpeg({
    required Uint8List pixels,
    required int width,
    required int height,
    required int quality,
  }) => Isolate.run(
    () => Uint8List.fromList(
      img.encodeJpg(
        img.Image.fromBytes(
          width: width,
          height: height,
          // Image.fromBytes reads the whole buffer, so a view into a larger
          // one is copied out first.
          bytes:
              (pixels.offsetInBytes == 0 &&
                          pixels.lengthInBytes == pixels.buffer.lengthInBytes
                      ? pixels
                      : Uint8List.fromList(pixels))
                  .buffer,
          numChannels: 4,
          order: img.ChannelOrder.bgra,
        ),
        quality: quality,
      ),
    ),
  );

  /// Page 1 as JPEG with its longest side at [maxDimension], plus the page
  /// count; null on every failure path.
  static Future<PdfPagePreview?> renderFirstPagePreview({
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
      // Own copy of the pixels, so they outlive the native buffer that
      // dispose frees.
      final Uint8List pixels;
      final int width;
      final int height;
      try {
        pixels = Uint8List.fromList(pageImage.pixels);
        width = pageImage.width;
        height = pageImage.height;
      } finally {
        pageImage.dispose();
      }
      return PdfPagePreview(
        jpeg: await encodeBgraJpeg(
          pixels: pixels,
          width: width,
          height: height,
          quality: quality,
        ),
        pageCount: document.pages.length,
      );
    } on Exception catch (e) {
      _log.warning('PDF page render failed: $e');
      return null;
    } finally {
      await document?.dispose();
    }
  }
}
