import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/image_resize_job.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Photo compressor (pure Dart). Gallery items route through the source
/// resolver's sized-thumbnail path (photo_manager decodes HEIC natively);
/// everything else decodes [source] with package:image. Returns null to
/// upload the original when already under the ceiling or undecodable.
class ImageCompressor implements MediaCompressor {
  ImageCompressor({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
  }) : _registry = registry,
       _cache = cache;

  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(ImageCompressor);

  @override
  Future<CompressionResult?> compress(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  ) async {
    final preset = photoPresetFor(level);
    if (preset == null) return null; // original: no compression
    try {
      if (item.sourceType == MediaSourceType.platformGallery) {
        // Ceiling rule: a gallery photo already under the long-edge cap uploads
        // its untouched original rather than a needlessly re-encoded (lossy)
        // JPEG. Only when the item's known dimensions clear the cap; unknown
        // dimensions fall through to the sized-thumbnail path below.
        final width = item.width;
        final height = item.height;
        if (width != null &&
            height != null &&
            (width > height ? width : height) <= preset.maxDimension) {
          return null;
        }
        // photo_manager returns a sized, JPEG-encoded rendition; HEIC-safe.
        final data = await _registry
            .resolverFor(item.sourceType)
            .resolveThumbnail(
              item,
              target: Size(
                preset.maxDimension.toDouble(),
                preset.maxDimension.toDouble(),
              ),
            );
        if (data is BytesData) return await _writeJpeg(data.bytes);
        return null;
      }
      return await _encode(source, item.originalFilename, preset);
    } on Exception catch (e) {
      _log.warning('Image compression failed for ${item.id}: $e');
      return null;
    }
  }

  /// Re-encode [source] down to the preset's ceiling, on a background isolate.
  ///
  /// The decode / resize / encode pass is pure-Dart package:image work, so
  /// inline it ran on the caller's isolate -- the media store worker's, which
  /// is the UI isolate. A single large frame is seconds of frozen app, and the
  /// worker loops over its whole queue (#1175). Passing the PATH rather than
  /// the bytes also keeps the original off this isolate's heap entirely.
  ///
  /// Both null returns are "upload the untouched original": one because
  /// package:image cannot read the source (HEIC on desktop), one because it is
  /// already within the ceiling and a re-encode would only lose quality.
  Future<CompressionResult?> _encode(
    File source,
    String? name,
    PhotoQualityPreset preset,
  ) async {
    final staged = await _cache.stagingFile();
    final result = await resizeToJpegFile(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: staged.path,
        declaredName: name,
        maxDimension: preset.maxDimension,
        jpegQuality: preset.jpegQuality,
        skipWhenUnderCeiling: true,
      ),
    );
    if (result.outcome != ImageResizeOutcome.written) {
      // The job turns a decoder throw into an outcome, so this log is the only
      // record left of a source package:image cannot read.
      final error = result.error;
      if (error != null) {
        _log.warning('Compression source not decodable: $error');
      }
      return null;
    }
    return CompressionResult(
      file: staged,
      ext: 'jpg',
      sizeBytes: result.sizeBytes,
    );
  }

  Future<CompressionResult> _writeJpeg(List<int> jpeg) async {
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(jpeg, flush: true);
    return CompressionResult(file: staged, ext: 'jpg', sizeBytes: jpeg.length);
  }
}
