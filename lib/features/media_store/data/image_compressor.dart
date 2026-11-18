import 'dart:io';
import 'dart:ui' show Size;

import 'package:image/image.dart' as img;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/image_resize_job.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/native_image_resize.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Photo compressor. Gallery items route through the source resolver's
/// sized-thumbnail path (photo_manager decodes HEIC natively); everything
/// else is decoded by [resize], Flutter's own codecs unless a test says
/// otherwise. Returns null to upload the original when already under the
/// ceiling or undecodable.
class ImageCompressor implements MediaCompressor {
  ImageCompressor({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
    Future<ImageResizeResult> Function(ImageResizeRequest request) resize =
        resizeToJpegFileNative,
  }) : _registry = registry,
       _cache = cache,
       _resize = resize;

  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;

  /// Decodes, scales and re-encodes one source (issue #4699). The engine's
  /// codecs scale as they decode, so a 50 MP photo peaks at about 145 MiB
  /// on its way to 2048 px, where package:image held the whole original and
  /// peaked at about 565 MiB. package:image stays behind it for the formats
  /// the engine rejects.
  final Future<ImageResizeResult> Function(ImageResizeRequest request) _resize;
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

  /// Re-encode [source] down to the preset's ceiling, off the UI isolate.
  ///
  /// The decode runs on the engine's threads and the JPEG encode on a
  /// background isolate; neither may run inline on the media store worker,
  /// which is the UI isolate, where a single large frame is seconds of frozen
  /// app (#1175). Passing the PATH rather than the bytes also keeps the
  /// original off this isolate's heap entirely.
  ///
  /// Both null returns are "upload the untouched original": one because
  /// neither decoder can read the source, one because it is already within
  /// the ceiling and a re-encode would only lose quality.
  Future<CompressionResult?> _encode(
    File source,
    String? name,
    PhotoQualityPreset preset,
  ) async {
    // A format package:image cannot read (HEIC) uploaded untouched before
    // the engine's codecs took over the decode, and only a JPEG's EXIF can
    // be carried into a rendition: re-encoded, it would lose its capture
    // time and location (issue #4699).
    if (name != null &&
        name.contains('.') &&
        img.findDecoderForNamedImage(name) == null) {
      return null;
    }
    final staged = await _cache.stagingFile();
    final result = await _resize(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: staged.path,
        declaredName: name,
        maxDimension: preset.maxDimension,
        jpegQuality: preset.jpegQuality,
        skipWhenUnderCeiling: true,
        keepJpegMetadata: true,
      ),
    );
    if (result.outcome != ImageResizeOutcome.written) {
      // The job turns a decoder throw into an outcome, so this log is the only
      // record left of a source neither decoder can read.
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
