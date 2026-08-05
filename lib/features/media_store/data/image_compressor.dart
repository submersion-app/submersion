import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:image/image.dart' as img;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
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
        if (data is BytesData) return _writeJpeg(data.bytes);
        return null;
      }
      final bytes = await source.readAsBytes();
      return _encode(bytes, item.originalFilename, preset);
    } on Exception catch (e) {
      _log.warning('Image compression failed for ${item.id}: $e');
      return null;
    }
  }

  Future<CompressionResult?> _encode(
    Uint8List bytes,
    String? name,
    PhotoQualityPreset preset,
  ) async {
    final decoded = name != null && name.contains('.')
        ? img.decodeNamedImage(name, bytes)
        : img.decodeImage(bytes);
    if (decoded == null) return null; // undecodable (e.g. HEIC on desktop)
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longest <= preset.maxDimension) return null; // ceiling: upload original
    final resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? preset.maxDimension : null,
      height: decoded.height > decoded.width ? preset.maxDimension : null,
    );
    return _writeJpeg(img.encodeJpg(resized, quality: preset.jpegQuality));
  }

  Future<CompressionResult> _writeJpeg(List<int> jpeg) async {
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(jpeg, flush: true);
    return CompressionResult(file: staged, ext: 'jpg', sizeBytes: jpeg.length);
  }
}
