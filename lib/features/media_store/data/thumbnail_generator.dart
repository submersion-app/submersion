import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/image_resize_job.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Best-effort thumbnail production for the upload pipeline (design spec
/// section 9 step 4). Only the gallery source hands back genuinely
/// pre-compressed thumbnail bytes; everything else (including bookmark
/// reads, which return full originals as bytes) is decoded and resized
/// here. Re-encoding drops EXIF (including GPS) from the thumb. Failure
/// never blocks the original's upload: every error path returns null.
class ThumbnailGenerator {
  ThumbnailGenerator({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
    PdfThumbRenderer? pdfRenderer,
  }) : _registry = registry,
       _cache = cache,
       _pdfRenderer = pdfRenderer ?? PdfPageRenderer.renderFirstPageJpeg;

  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final PdfThumbRenderer _pdfRenderer;
  final _log = LoggerService.forClass(ThumbnailGenerator);

  static const int maxDimension = 512;
  static const int jpegQuality = 80;

  Future<File?> generateFor(MediaItem item) async {
    try {
      final resolver = _registry.resolverFor(item.sourceType);
      final data = await resolver.resolveThumbnail(
        item,
        target: Size(maxDimension.toDouble(), maxDimension.toDouble()),
      );
      if (item.isDocument) {
        // Opaque documents have no thumbnail; PDFs get a page-1 render.
        if (!item.isPdf) return null;
        return await switch (data) {
          FileData(file: final f) => _stagePdfThumb(file: f),
          BytesData(bytes: final b) => _stagePdfThumb(bytes: b),
          NetworkData() || UnavailableData() => null,
        };
      }
      switch (data) {
        case BytesData(bytes: final b)
            when item.sourceType == MediaSourceType.platformGallery:
          // photo_manager thumbnails are already sized and compressed.
          final staged = await _cache.stagingFile();
          await staged.writeAsBytes(b, flush: true);
          return staged;
        case BytesData(bytes: final b)
            when item.sourceType == MediaSourceType.serviceConnector:
          // Connector renditions are always JPEG regardless of the
          // original's filename: a video row carries a .mp4 name but its
          // rendition is a JPEG poster frame, and decoding by that name
          // would always fail.
          return await _resizeToJpeg(b, 'rendition.jpg');
        case BytesData(bytes: final b):
          // Non-gallery BytesData is the original (e.g. a bookmark read on
          // iOS/macOS): resize and re-encode so full-size bytes and their
          // EXIF/GPS never masquerade as a thumb.
          return await _resizeToJpeg(b, item.originalFilename);
        case FileData(file: final f):
          // Pass the PATH, not the bytes: the isolate reads the file itself,
          // so a 40 MB original never crosses the message channel and is
          // never resident on the UI isolate at all.
          return await _resizeFileToJpeg(f, item.originalFilename);
        case NetworkData():
        case UnavailableData():
          return null;
      }
    } on Exception catch (e) {
      _log.warning('Thumbnail generation failed for ${item.id}: $e');
      return null;
    }
  }

  Future<File?> _stagePdfThumb({File? file, Uint8List? bytes}) async {
    final jpeg = await _pdfRenderer(
      file: file,
      bytes: bytes,
      maxDimension: maxDimension,
      quality: jpegQuality,
    );
    if (jpeg == null) return null;
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(jpeg, flush: true);
    return staged;
  }

  /// Decode, resize and re-encode [bytes] as a thumbnail JPEG.
  ///
  /// Hands the whole codec pass to a background isolate. It is pure-Dart
  /// package:image work, so inline it ran on the caller's isolate -- and the
  /// caller is the upload worker on the UI isolate, where one 24 MP frame is
  /// seconds of frozen app (#1175). Decoding by declared extension is
  /// preserved inside the job: the generic decoder probes every format and
  /// permissive ones (TGA) accept arbitrary bytes.
  Future<File?> _resizeToJpeg(Uint8List bytes, String? name) async {
    final staged = await _cache.stagingFile();
    final result = await resizeToJpegFile(
      ImageResizeRequest.fromBytes(
        bytes: bytes,
        destinationPath: staged.path,
        declaredName: name,
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
      ),
    );
    return _staged(staged, result);
  }

  /// [_resizeToJpeg] for a source that is already a file on disk.
  Future<File?> _resizeFileToJpeg(File source, String? name) async {
    final staged = await _cache.stagingFile();
    final result = await resizeToJpegFile(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: staged.path,
        declaredName: name,
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
      ),
    );
    return _staged(staged, result);
  }

  /// The staged file on success, null otherwise.
  ///
  /// The job normalises a decoder throw into an outcome, so the reason it
  /// gives is the only record left of a source package:image cannot read;
  /// without this the class would go silent where it used to log. Nothing to
  /// clean up on failure: `stagingFile()` mints a path without creating it,
  /// and the job writes only on success.
  File? _staged(File staged, ImageResizeResult result) {
    if (result.outcome == ImageResizeOutcome.written) return staged;
    final error = result.error;
    if (error != null) _log.warning('Thumbnail source not decodable: $error');
    return null;
  }
}
